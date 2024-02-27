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
    const ENOT_ENOUGH_COINS: u64 = 5;
    const EINSUFFICIENT_PERMISSIONS: u64 = 6;
    const EGAME_ALREADY_STARTED: u64 = 7;
    const ETABLE_IS_FULL: u64 = 8;

    // Game states
    const GAMESTATE_OPEN: u64 = 0;
    const GAMESTATE_IN_PROGRESS: u64 = 1;
    const GAMESTATE_CLOSED: u64 = 2;

    struct GameMetadata has store {
        id: u64,
        room_name: string::String,
        pot: u64,
        state: u64,
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

    public fun assert_is_initialized(addr: address) {
        assert!(exists<GameState>(addr), ENOT_INITIALIZED);
    }

    public fun assert_uninitialized(addr: address) {
        assert!(!exists<GameState>(addr), EALREADY_INITIALIZED);
    } 

    // Initialize the game state and add the game to the global state
    public fun initialize(acc: &signer) {
        let addr = signer::address_of(acc);

        assert_is_owner(addr);
        assert_uninitialized(addr);
        
        let gamestate: GameState = GameState {
            games: simple_map::new(),
        };

        let game_metadata = GameMetadata {
            id: 0,
            room_name: string::utf8(b"room1"),
            pot: 0,
            state: GAMESTATE_OPEN,
            winner: @0x0,
            players: vector::empty(),
        };

        simple_map::add(&mut gamestate.games, game_metadata.id, game_metadata);

        move_to(acc, gamestate);
    }

    // When user joins and places a bet
    public entry fun join_game(from: &signer, game_id: u64, amount: u64) acquires GameState {
        let from_acc_balance:u64 = coin::balance<AptosCoin>(signer::address_of(from));
        let addr = signer::address_of(from);

        assert!(amount <= from_acc_balance, ENOT_ENOUGH_COINS);

        let gamestate = borrow_global_mut<GameState>(@poker);

        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        assert!(vector::length(&game_metadata.players) < 4, ETABLE_IS_FULL);

        assert!(game_metadata.state == GAMESTATE_OPEN, EGAME_ALREADY_STARTED);
        
        aptos_account::transfer(from, @poker, amount); 

        vector::push_back(&mut game_metadata.players, addr);
        game_metadata.pot = game_metadata.pot + amount;

    }

    /*

    .-------------------------------.
    |           T E S T S           |
    '-------------------------------'

    */

    #[test(admin = @poker, aptos_framework = @0x1, account1 = @0x3, account2 = @0x4, account3 = @0x5, account4 = @0x6)]
    fun test_join_game(account1: &signer, account2: &signer, account3: &signer, account4: &signer,
    admin: &signer, aptos_framework: &signer)
    acquires GameState {
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

        initialize(admin); // Ensure game is initialized
        let game_id = 0; // Assuming the game you want to join

        // Simulate Joining
        join_game(account1, 0, 50);
        join_game(account2, 0, 60);
        join_game(account3, 0, 70);
        join_game(account4, 0, 80);

        // Fetch and Print GameState
        let gamestate = borrow_global<GameState>(@poker); 
        let game_metadata = simple_map::borrow<u64, GameMetadata>(&gamestate.games, &game_id); 

        debug::print(&game_metadata.id);
        debug::print(&game_metadata.room_name);
        debug::print(&game_metadata.pot);
        debug::print(&game_metadata.state);
        debug::print(&game_metadata.winner);
        debug::print(&game_metadata.players);

        assert!(game_metadata.id == copy game_id, 0);
        assert!(vector::length(&game_metadata.players) == 4, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
}