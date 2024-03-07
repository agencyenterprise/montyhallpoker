module poker::poker_manager {
    use 0x1::signer;
    use 0x1::vector;
    use 0x1::coin;
    use 0x1::aptos_coin::AptosCoin; 
    use 0x1::aptos_account;
    use 0x1::aptos_coin;
    use std::account;
    use std::string;
    use std::simple_map::{SimpleMap,Self};
    use aptos_std::debug;
    use aptos_framework::event;

    /// Error codes
    const EINVALID_MOVE: u64 = 0;
    const EINSUFFICIENT_BALANCE: u64 = 1;
    const EINVALID_GAME: u64 = 2;
    const EALREADY_INITIALIZED: u64 = 3;
    const ENOT_INITIALIZED: u64 = 4;
    const EINSUFFICIENT_PERMISSIONS: u64 = 5;
    const EGAME_ALREADY_STARTED: u64 = 6;
    const ETABLE_IS_FULL: u64 = 7;
    const EALREADY_IN_GAME: u64 = 8;
    const EGAME_NOT_READY: u64 = 9;
    const EINSUFFICIENT_BALANCE_FOR_STAKE: u64 = 10;
    const ENOT_IN_GAME: u64 = 11;

    // Game states
    const GAMESTATE_OPEN: u64 = 0;
    const GAMESTATE_IN_PROGRESS: u64 = 1;
    const GAMESTATE_CLOSED: u64 = 2;

    // Stakes
    const LOW_STAKES: u64 = 5000000; // More or less 0.05 APT (1 APT = $10)
    const MEDIUM_STAKES: u64 = 30000000; // More or less 0.3 APT
    const HIGH_STAKES: u64 = 100000000; // More or less 1 APT

    // Actions
    const FOLD: u64 = 0;
    const CHECK: u64 = 1;
    const CALL: u64 = 2;
    const RAISE: u64 = 3;
    const ALL_IN: u64 = 4;
    const BET: u64 = 5;

    // Stages
    const STAGE_PREFLOP: u8 = 0;
    const STAGE_FLOP: u8 = 1;
    const STAGE_TURN: u8 = 2;
    const STAGE_RIVER: u8 = 3;

    // Structs
    struct Hand has drop, copy {
        suit: u8,
        value: u8,
        suit_string: vector<u8>,
        value_string: vector<u8>,

    }

    struct Player has drop, copy {
        id: address,
        hand: vector<Hand>,

    }

    struct LastRaiser has drop, copy {
        playerIndex: address,
        playerMove: u32,
    }
    
    struct GameMetadata has drop, copy, store {
        players: vector<Player>,
        deck: vector<Hand>,
        community: vector<Hand>,
        currentRound: u8,
        stage: u8,
        currentPlayerIndex: u8,
        continueBetting: bool,
        order: vector<Hand>,
        playerMove: u32,
        lastRaiser: Option<LastRaiser>,
        gameEnded: bool,
        seed: u64,
        id: u64,
        room_id: u64,
        stake: u64,
        pot: u64,
        state: u64,
        turn: vector<address>,
        hands: vector<u64>,
        current_bet: u64,
        community_cards: vector<u64>,
        continueBetting: bool,
        winner: address,
    }

    struct GameState has key {
        games: SimpleMap<u64, GameMetadata>
    }

    struct UserGames has key {
        games: vector<u64>,
    }

    // Events
    #[event]
    struct PlayerJoinsGame has drop, store {
        account: address,
        game_id: u64,
        amount: u64,
    }

    #[event]
    struct PlayerLeavesGame has drop, store {
        account: address,
        game_id: u64,
    }

    #[event]
    struct PlayerPerformsActionEvent has drop, store {
        account: address,
        game_id: u64,
    }

    #[event]
    struct GameEndsEvent has drop, store {
        account: address,
        game_id: u64,
    }

    #[event]
    struct GameStartsEvent has drop, store {
        account: address,
        game_id: u64,
    }

    public fun assert_is_owner(addr: address) {
        assert!(addr == @poker, EINSUFFICIENT_PERMISSIONS);
    }

    public fun assert_is_initialized() {
        assert!(exists<GameState>(@poker), ENOT_INITIALIZED);
    }

    public fun assert_uninitialized() {
        assert!(!exists<GameState>(@poker), EALREADY_INITIALIZED);
    }

    public fun assert_account_is_not_in_open_game(addr: address) acquires UserGames, GameState {
        if (!exists<UserGames>(addr)) {
            return
        } else {
            assert!(exists<UserGames>(addr), EALREADY_IN_GAME);
            let user_games = borrow_global<UserGames>(addr);
            let games = user_games.games;
            let len = vector::length(&games);
            // if last one is closed, all good
            if (len > 0) {
                let last_game_id = *vector::borrow<u64>(&games, len - 1);
                let game_metadata = get_game_metadata_by_id(last_game_id);
                assert!(game_metadata.state == GAMESTATE_CLOSED, EALREADY_IN_GAME);
            }
        }
    }

    // Returns the game metadata for a given game id
    public fun get_game_metadata_by_id(game_id: u64): GameMetadata acquires GameState {
        let gamestate = borrow_global<GameState>(@poker);
        let game_metadata_ref = simple_map::borrow<u64, GameMetadata>(&gamestate.games, &game_id);
        *game_metadata_ref // dereference the value before returning it
    }

    // Returns the current game (latest one) for a given user
    public fun get_account_current_game(addr: address): u64 acquires UserGames {
        let user_games = borrow_global<UserGames>(addr);
        let games = user_games.games;
        let len = vector::length(&games);
        if (len > 0) {
            *vector::borrow<u64>(&games, len - 1)
        } else {
            0
        }
    }

    // Initialize the game state and add the game to the global state
    fun init_module(acc: &signer) {
        let addr = signer::address_of(acc);

        assert_is_owner(addr);
        assert_uninitialized();
        
        let gamestate: GameState = GameState {
            games: simple_map::new(),
        };

        let game_metadata = GameMetadata {
            id: 1,
            room_id: 1,
            pot: 0,
            state: GAMESTATE_OPEN,
            stake: LOW_STAKES,
            turn: vector::empty(),
            winner: @0x0,
            players: vector::empty(),
        };

        simple_map::add(&mut gamestate.games, game_metadata.id, game_metadata);

        move_to(acc, gamestate);
    }

    public fun start_game(game_id: u64) acquires GameState {
        let gamestate = borrow_global_mut<GameState>(@poker);
        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);
        assert!(vector::length(&game_metadata.players) == 4, EGAME_NOT_READY);
        game_metadata.state = GAMESTATE_IN_PROGRESS;
    }

    public fun winner(winner_address: address) acquires GameState {
        let gamestate = borrow_global_mut<GameState>(@poker);
        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &1);
        game_metadata.winner = winner_address;
        game_metadata.state = GAMESTATE_CLOSED;
    }

    public entry fun create_game(acc: &signer, room_id: u64, stake: u64) acquires GameState {
        let addr = signer::address_of(acc);
        assert_is_initialized();
        assert_is_owner(addr);

        let gamestate = borrow_global_mut<GameState>(@poker);

        // Add a new game to the global state
        let game_metadata = GameMetadata {
            id: vector::length<u64>(&simple_map::keys(&gamestate.games)) + 1, // Type parameter after function name
            room_id: room_id,
            pot: 0,
            state: GAMESTATE_OPEN,
            stake: stake,
            turn: vector::empty(),
            winner: @0x0,
            players: vector::empty(),
        };

        simple_map::add(&mut gamestate.games, game_metadata.id, game_metadata);
    }

    // When user joins and places a bet
    public entry fun join_game(from: &signer, game_id: u64, amount: u64) acquires GameState, UserGames {
        let from_acc_balance:u64 = coin::balance<AptosCoin>(signer::address_of(from));
        let addr = signer::address_of(from);

        event::emit(PlayerJoinsGame {
            account: addr,
            game_id: game_id,
            amount: amount,
        });

        assert!(amount <= from_acc_balance, EINSUFFICIENT_BALANCE);
        
        assert_account_is_not_in_open_game(addr);

        let gamestate = borrow_global_mut<GameState>(@poker);

        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        assert!(vector::length(&game_metadata.players) < 4, ETABLE_IS_FULL);

        assert!(game_metadata.state == GAMESTATE_OPEN, EGAME_ALREADY_STARTED);

        assert!(amount >= game_metadata.stake, EINSUFFICIENT_BALANCE_FOR_STAKE);
        
        aptos_account::transfer(from, @poker, amount); 

        vector::push_back(&mut game_metadata.players, addr);
        game_metadata.pot = game_metadata.pot + amount;

        if (!exists<UserGames>(addr)) {
            move_to(from, UserGames {
                games: vector[game_id],
            })
        } else {
            let user_games = borrow_global_mut<UserGames>(addr);
            vector::push_back(&mut user_games.games, game_id);
        }
    }

    public entry fun leave_game(from: &signer, game_id: u64) acquires GameState, UserGames {
        let addr = signer::address_of(from);
        assert_is_initialized();

        let gamestate = borrow_global_mut<GameState>(@poker);
        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        let (is_player_in_game, player_index) = vector::index_of(&game_metadata.players, &addr);
        assert!(is_player_in_game, ENOT_IN_GAME);

        vector::remove(&mut game_metadata.players, player_index);

        event::emit(PlayerLeavesGame {
            account: addr,
            game_id: game_id
        });

        if (exists<UserGames>(addr)) {
            let user_games = borrow_global_mut<UserGames>(addr);
            (is_player_in_game, player_index) = vector::index_of(&user_games.games, &game_id);
            if (is_player_in_game) {
                let game_index = player_index;
                vector::remove(&mut user_games.games, game_index);
            }
        }
    }

    //public entry fun perform_action(from: &signer, game_id: u64, action: u64, amount: u64) acquires GameState {
        /* let from_acc_balance:u64 = coin::balance<AptosCoin>(signer::address_of(from));
        let addr = signer::address_of(from);

        assert!(amount <= from_acc_balance, EINSUFFICIENT_BALANCE);

        let gamestate = borrow_global_mut<GameState>(@poker);

        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        assert!(game_metadata.state == GAMESTATE_OPEN, EINVALID_MOVE);
        
        aptos_account::transfer(from, @poker, amount); 

        game_metadata.pot = game_metadata.pot + amount; */
    //}

    /*

    .-------------------------------.
    |           T E S T S           |
    '-------------------------------'

    */

    // Only an admin can create a game
    #[test(admin = @poker, nonadmin = @0x5)]
    #[expected_failure(abort_code = EINSUFFICIENT_PERMISSIONS)]
    fun test_create_game_not_admin(nonadmin: &signer, admin: &signer) acquires GameState {
        init_module(admin);

        create_game(nonadmin, 2, LOW_STAKES);
    }

    // Happy path where 4 players join the game normally

    #[test(admin = @poker, aptos_framework = @0x1, account1 = @0x3, account2 = @0x4, account3 = @0x5, account4 = @0x6)]
    fun test_join_game(account1: &signer, account2: &signer, account3: &signer, account4: &signer,
    admin: &signer, aptos_framework: &signer)
    acquires GameState, UserGames {
        // Setup 

        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos_framework);
        let aptos_framework_address = signer::address_of(aptos_framework);
        account::create_account_for_test(aptos_framework_address);

        let player1 = account::create_account_for_test(signer::address_of(account1));
        let player2 = account::create_account_for_test(signer::address_of(account2));
        let player3 = account::create_account_for_test(signer::address_of(account3));
        let player4 = account::create_account_for_test(signer::address_of(account4));

        coin::register<AptosCoin>(&player1);
        coin::register<AptosCoin>(&player2);
        coin::register<AptosCoin>(&player3);
        coin::register<AptosCoin>(&player4);

        aptos_coin::mint(aptos_framework, signer::address_of(account1), 90000000000);
        aptos_coin::mint(aptos_framework, signer::address_of(account2), 90000000000);
        aptos_coin::mint(aptos_framework, signer::address_of(account3), 90000000000);
        aptos_coin::mint(aptos_framework, signer::address_of(account4), 90000000000);

        init_module(admin);
        let game_id = 1;

        // Simulate Joining
        join_game(account1, 1, 5000000);
        join_game(account2, 1, 6000000);
        join_game(account3, 1, 7000000);
        join_game(account4, 1, 8000000);

        // Fetch and Print GameState
        let gamestate = borrow_global<GameState>(@poker); 
        let game_metadata = simple_map::borrow<u64, GameMetadata>(&gamestate.games, &game_id);

        debug::print(&game_metadata.id);
        debug::print(&game_metadata.room_id);
        debug::print(&game_metadata.pot);
        debug::print(&game_metadata.state);
        debug::print(&game_metadata.winner);
        debug::print(&game_metadata.players);

        // Make sure the game is in the global state and has the correct number of players
        assert!(game_metadata.id == copy game_id, 0);
        assert!(vector::length(&game_metadata.players) == 4, 0);

        let user1_games = borrow_global<UserGames>(signer::address_of(account1));
        let user2_games = borrow_global<UserGames>(signer::address_of(account2));
        let user3_games = borrow_global<UserGames>(signer::address_of(account3));
        let user4_games = borrow_global<UserGames>(signer::address_of(account4));

        debug::print(&user1_games.games);

        // Make sure the users have the game in their list of games
        assert!(vector::length(&user1_games.games) == 1, 0);
        assert!(vector::length(&user2_games.games) == 1, 0);
        assert!(vector::length(&user3_games.games) == 1, 0);
        assert!(vector::length(&user4_games.games) == 1, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    // User tries to join full table

    #[test(admin = @poker, aptos_framework = @0x1, account1 = @0x3, account2 = @0x4, 
    account3 = @0x5, account4 = @0x6, account5 = @0x7)]
    #[expected_failure(abort_code = ETABLE_IS_FULL)]
    fun test_join_full_game(account1: &signer, account2: &signer, account3: &signer,
    account4: &signer, account5: &signer,
    admin: &signer, aptos_framework: &signer)
    acquires GameState, UserGames {
        // Setup 

        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos_framework);
        let aptos_framework_address = signer::address_of(aptos_framework);
        account::create_account_for_test(aptos_framework_address);

        let player1 = account::create_account_for_test(signer::address_of(account1));
        let player2 = account::create_account_for_test(signer::address_of(account2));
        let player3 = account::create_account_for_test(signer::address_of(account3));
        let player4 = account::create_account_for_test(signer::address_of(account4));
        let player5 = account::create_account_for_test(signer::address_of(account5));

        coin::register<AptosCoin>(&player1);
        coin::register<AptosCoin>(&player2);
        coin::register<AptosCoin>(&player3);
        coin::register<AptosCoin>(&player4);
        coin::register<AptosCoin>(&player5);

        aptos_coin::mint(aptos_framework, signer::address_of(account1), 90000000000);
        aptos_coin::mint(aptos_framework, signer::address_of(account2), 90000000000);
        aptos_coin::mint(aptos_framework, signer::address_of(account3), 90000000000);
        aptos_coin::mint(aptos_framework, signer::address_of(account4), 90000000000);
        aptos_coin::mint(aptos_framework, signer::address_of(account5), 90000000000);

        init_module(admin);

        // Simulate Joining
        join_game(account1, 1, 5000000);
        join_game(account2, 1, 6000000);
        join_game(account3, 1, 7000000);
        join_game(account4, 1, 8000000);
        join_game(account5, 1, 6500000); // This should fail because the table is full

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    // User tries to join without enough coins

    #[test(admin = @poker, aptos_framework = @0x1, account1 = @0x3)]
    #[expected_failure(abort_code = EINSUFFICIENT_BALANCE)]
    fun test_join_without_balance(account1: &signer, admin: &signer, aptos_framework: &signer)
    acquires GameState, UserGames {
        // Setup 

        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos_framework);
        let aptos_framework_address = signer::address_of(aptos_framework);
        account::create_account_for_test(aptos_framework_address);

        let player1 = account::create_account_for_test(signer::address_of(account1));

        coin::register<AptosCoin>(&player1);

        aptos_coin::mint(aptos_framework, signer::address_of(account1), 300);

        init_module(admin);

        // Simulate Joining
        join_game(account1, 1, 5000000);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    // User cannot join a game if they are already in a in-progress game

    #[test(admin = @poker, aptos_framework = @0x1, account1 = @0x3)]
    #[expected_failure(abort_code = EALREADY_IN_GAME)]
    fun test_join_while_in_game(account1: &signer, admin: &signer, aptos_framework: &signer) acquires GameState, UserGames {
        // Setup 

        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos_framework);
        let aptos_framework_address = signer::address_of(aptos_framework);
        account::create_account_for_test(aptos_framework_address);

        let player1 = account::create_account_for_test(signer::address_of(account1));

        coin::register<AptosCoin>(&player1);

        aptos_coin::mint(aptos_framework, signer::address_of(account1), 90000000000);

        init_module(admin);

        // Create game
        create_game(admin, 2, LOW_STAKES);

        // Simulate Joining
        join_game(account1, 1, 5000000);

        // Simulate Joining again
        join_game(account1, 2, 5000000);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    // When a game starts with 4 players, it should succeed

    #[test(admin = @poker, aptos_framework = @0x1, account1 = @0x3, account2 = @0x4, account3 = @0x5, account4 = @0x6)]
    fun test_game_starts(account1: &signer, account2: &signer, account3: &signer, account4: &signer,
    admin: &signer, aptos_framework: &signer) acquires UserGames, GameState {
        // Setup 

        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos_framework);
        let aptos_framework_address = signer::address_of(aptos_framework);
        account::create_account_for_test(aptos_framework_address);

        let player1 = account::create_account_for_test(signer::address_of(account1));
        let player2 = account::create_account_for_test(signer::address_of(account2));
        let player3 = account::create_account_for_test(signer::address_of(account3));
        let player4 = account::create_account_for_test(signer::address_of(account4));

        coin::register<AptosCoin>(&player1);
        coin::register<AptosCoin>(&player2);
        coin::register<AptosCoin>(&player3);
        coin::register<AptosCoin>(&player4);

        aptos_coin::mint(aptos_framework, signer::address_of(account1), 90000000000);
        aptos_coin::mint(aptos_framework, signer::address_of(account2), 90000000000);
        aptos_coin::mint(aptos_framework, signer::address_of(account3), 90000000000);
        aptos_coin::mint(aptos_framework, signer::address_of(account4), 90000000000);

        init_module(admin);

        // Create game
        create_game(admin, 2, LOW_STAKES);

        // Simulate Joining
        join_game(account1, 1, 5000000);
        join_game(account2, 1, 6000000);
        join_game(account3, 1, 7000000);
        join_game(account4, 1, 8000000);

        // Start game
        start_game(1);

        let gamestate = borrow_global<GameState>(@poker);
        let game_metadata = simple_map::borrow<u64, GameMetadata>(&gamestate.games, &1);

        assert!(game_metadata.state == GAMESTATE_IN_PROGRESS, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    // When a game starts with less than 4 players, it should fail

    #[test(admin = @poker, aptos_framework = @0x1, account1 = @0x3)]
    #[expected_failure(abort_code = EGAME_NOT_READY)]
    fun test_game_start_fails_too_few(account1: &signer, admin: &signer, aptos_framework: &signer) acquires UserGames, GameState {
        // Setup 

        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos_framework);
        let aptos_framework_address = signer::address_of(aptos_framework);
        account::create_account_for_test(aptos_framework_address);

        let player1 = account::create_account_for_test(signer::address_of(account1));

        coin::register<AptosCoin>(&player1);

        aptos_coin::mint(aptos_framework, signer::address_of(account1), 90000000000);

        init_module(admin);

        // Simulate Joining
        join_game(account1, 1, 5000000);

        // Start game
        start_game(1);

        let gamestate = borrow_global<GameState>(@poker);
        let game_metadata = simple_map::borrow<u64, GameMetadata>(&gamestate.games, &1);

        assert!(game_metadata.state == GAMESTATE_IN_PROGRESS, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    // When a winner is declared, the game state is updated

    #[test(admin = @poker, aptos_framework = @0x1, account1 = @0x3)]
    fun test_winner_declared(account1: &signer, admin: &signer, aptos_framework: &signer) acquires GameState, UserGames {
        // Setup 

        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos_framework);
        let aptos_framework_address = signer::address_of(aptos_framework);
        account::create_account_for_test(aptos_framework_address);

        let player1 = account::create_account_for_test(signer::address_of(account1));

        coin::register<AptosCoin>(&player1);

        aptos_coin::mint(aptos_framework, signer::address_of(account1), 90000000000);

        init_module(admin);

        // Create game
        create_game(admin, 2, LOW_STAKES);

        // Simulate Joining
        join_game(account1, 1, 5000000);

        // Declare winner
        winner(signer::address_of(account1));

        let gamestate = borrow_global<GameState>(@poker);
        let game_metadata = simple_map::borrow<u64, GameMetadata>(&gamestate.games, &1);

        assert!(game_metadata.winner == signer::address_of(account1), 0);
        assert!(game_metadata.state == GAMESTATE_CLOSED, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(admin = @poker, aptos_framework = @0x1, account1 = @0x3)]
    fun test_leave_game(account1: &signer, admin: &signer, aptos_framework: &signer)
    acquires GameState, UserGames {
        // Setup
        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos_framework);
        let aptos_framework_address = signer::address_of(aptos_framework);
        account::create_account_for_test(aptos_framework_address);

        let player1 = account::create_account_for_test(signer::address_of(account1));

        coin::register<AptosCoin>(&player1);

        aptos_coin::mint(aptos_framework, signer::address_of(account1), 90000000000);

        init_module(admin);
        let game_id = 1;

        // Player joins the game
        join_game(account1, game_id, 5000000);

        // Fetch and Print GameState before leaving
        let gamestate_before_leaving = borrow_global<GameState>(@poker);
        let game_metadata_before_leaving = simple_map::borrow<u64, GameMetadata>(&gamestate_before_leaving.games, &game_id);

        debug::print(&game_metadata_before_leaving.players);

        // Ensure the player is in the game
        assert!(vector::contains(&game_metadata_before_leaving.players, &signer::address_of(account1)), 0);

        // Player leaves the game
        leave_game(account1, game_id);

        // Fetch and Print GameState after leaving
        let gamestate_after_leaving = borrow_global<GameState>(@poker);
        let game_metadata_after_leaving = simple_map::borrow<u64, GameMetadata>(&gamestate_after_leaving.games, &game_id);

        debug::print(&game_metadata_after_leaving.players);

        // Ensure the game has no players
        assert!(game_metadata.state == GAMESTATE_OPEN, EGAME_ALREADY_STARTED);
        assert!(vector::length(&game_metadata_after_leaving.players) == 0, 0);

        // Ensure the player's UserGames struct no longer contains the game ID
        let user1_games = borrow_global<UserGames>(signer::address_of(account1));
        assert!(!vector::contains(&user1_games.games, &game_id), 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

}