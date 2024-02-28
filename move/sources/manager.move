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

    /// Error codes
    const EINVALID_MOVE: u64 = 0;
    const EINSUFFICIENT_BALANCE: u64 = 1;
    const EINVALID_GAME: u64 = 2;
    const EALREADY_INITIALIZED: u64 = 3;
    const ENOT_INITIALIZED: u64 = 4;
    const EINSUFFICIENT_PERMISSIONS: u64 = 5;
    const EGAME_ALREADY_STARTED: u64 = 6;
    const ETABLE_IS_FULL: u64 = 7;

    // Game states
    const GAMESTATE_OPEN: u64 = 0;
    const GAMESTATE_IN_PROGRESS: u64 = 1;
    const GAMESTATE_CLOSED: u64 = 2;

    // Stakes
    const LOW_STAKES: u64 = 25; // 25 cents
    const MEDIUM_STAKES: u64 = 100; // 1 dollar
    const HIGH_STAKES: u64 = 1000; // 10 dollars

    struct GameMetadata has store, copy {
        id: u64,
        room_name: string::String,
        stake: u64,
        pot: u64,
        state: u64,
        turn: address,
        winner: address,
        players: vector<address>,
    }

    struct GameState has key {
        games: SimpleMap<u64, GameMetadata>,
    }

    struct UserGames has key {
        games: vector<u64>,
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

    public fun assert_account_is_not_in_game(addr: address, game_id: u64) {
        let user_games = borrow_global<UserGames>(addr);
        let games = user_games.games;
        let len = vector::length(&games);
        if (len > 0) {
            for (let i = 0; i < len; i = i + 1) {
                let game = *vector::borrow<u64>(&games, i);
                assert!(game != game_id, EINVALID_MOVE);
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
    public fun initialize(acc: &signer) {
        let addr = signer::address_of(acc);

        assert_is_owner(addr);
        assert_uninitialized();
        
        let gamestate: GameState = GameState {
            games: simple_map::new(),
        };

        let game_metadata = GameMetadata {
            id: 1,
            room_name: string::utf8(b"room1"),
            pot: 0,
            state: GAMESTATE_OPEN,
            stake: LOW_STAKES,
            turn: @0x0,
            winner: @0x0,
            players: vector::empty(),
        };

        simple_map::add(&mut gamestate.games, game_metadata.id, game_metadata);

        move_to(acc, gamestate);
    }

    public entry fun create_game(acc: &signer, room_name: string::String) acquires GameState {
        let addr = signer::address_of(acc);
        assert_is_initialized();
        assert_is_owner(addr);

        let gamestate = borrow_global_mut<GameState>(@poker);
        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &0);

        game_metadata.room_name = room_name;
    }

    // When user joins and places a bet
    public entry fun join_game(from: &signer, game_id: u64, amount: u64) acquires GameState, UserGames {
        let from_acc_balance:u64 = coin::balance<AptosCoin>(signer::address_of(from));
        let addr = signer::address_of(from);

        assert!(amount <= from_acc_balance, EINSUFFICIENT_BALANCE);

        let gamestate = borrow_global_mut<GameState>(@poker);

        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);



        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        assert!(vector::length(&game_metadata.players) < 4, ETABLE_IS_FULL);

        assert!(game_metadata.state == GAMESTATE_OPEN, EGAME_ALREADY_STARTED);
        
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

    public entry fun place_bet(from: &signer, amount: u64) {
        /* let from_acc_balance:u64 = coin::balance<AptosCoin>(signer::address_of(from));
        let addr = signer::address_of(from);

        assert!(amount <= from_acc_balance, EINSUFFICIENT_BALANCE);

        let gamestate = borrow_global_mut<GameState>(@poker);

        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        assert!(game_metadata.state == GAMESTATE_OPEN, EINVALID_MOVE);
        
        aptos_account::transfer(from, @poker, amount); 

        game_metadata.pot = game_metadata.pot + amount; */
    }

    /*

    .-------------------------------.
    |           T E S T S           |
    '-------------------------------'

    */

    // Only an admin can create a game
    #[test(admin = @poker, nonadmin = @0x5)]
    #[expected_failure(abort_code = EINSUFFICIENT_PERMISSIONS)]
    fun test_create_game_not_admin(nonadmin: &signer, admin: &signer) acquires GameState {
        initialize(admin);

        create_game(nonadmin, string::utf8(b"room1"));
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

        aptos_coin::mint(aptos_framework, signer::address_of(account1), 300);
        aptos_coin::mint(aptos_framework, signer::address_of(account2), 300);
        aptos_coin::mint(aptos_framework, signer::address_of(account3), 300);
        aptos_coin::mint(aptos_framework, signer::address_of(account4), 300);

        initialize(admin);
        let game_id = 1;

        // Simulate Joining
        join_game(account1, 1, 50);
        join_game(account2, 1, 60);
        join_game(account3, 1, 70);
        join_game(account4, 1, 80);

        // Fetch and Print GameState
        let gamestate = borrow_global<GameState>(@poker); 
        let game_metadata = simple_map::borrow<u64, GameMetadata>(&gamestate.games, &game_id);

        debug::print(&game_metadata.id);
        debug::print(&game_metadata.room_name);
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

        aptos_coin::mint(aptos_framework, signer::address_of(account1), 300);
        aptos_coin::mint(aptos_framework, signer::address_of(account2), 300);
        aptos_coin::mint(aptos_framework, signer::address_of(account3), 300);
        aptos_coin::mint(aptos_framework, signer::address_of(account4), 300);
        aptos_coin::mint(aptos_framework, signer::address_of(account5), 300);

        initialize(admin);

        // Simulate Joining
        join_game(account1, 1, 50);
        join_game(account2, 1, 60);
        join_game(account3, 1, 70);
        join_game(account4, 1, 80);
        join_game(account5, 1, 65); // This should fail because the table is full

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    // User tries to join without enough coins

    #[test(admin = @poker, aptos_framework = @0x1, account1 = @0x3, account2 = @0x4, account3 = @0x5, account4 = @0x6)]
    #[expected_failure(abort_code = EINSUFFICIENT_BALANCE)]
    fun test_join_without_balance(account1: &signer, account2: &signer, account3: &signer, account4: &signer,
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

        aptos_coin::mint(aptos_framework, signer::address_of(account1), 300);
        aptos_coin::mint(aptos_framework, signer::address_of(account2), 300);
        aptos_coin::mint(aptos_framework, signer::address_of(account3), 300);
        aptos_coin::mint(aptos_framework, signer::address_of(account4), 300);

        initialize(admin);

        // Simulate Joining
        join_game(account1, 1, 50);
        join_game(account2, 1, 60);
        join_game(account3, 1, 800); // This should fail because the user doesn't have enough coins
        join_game(account4, 1, 80);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

}