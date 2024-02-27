module poker::poker_manager {
    use 0x1::signer;
    use 0x1::vector;
    use 0x1::coin;
    use 0x1::aptos_coin::AptosCoin; 
    use 0x1::aptos_account;
    use 0x1::aptos_coin;
    use aptos_std::debug;
    use std::error;
    use std::string;
    use std::simple_map::{SimpleMap,Self};

    /// Error codes
    const EINVALID_MOVE: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2;
    const EINVALID_GAME: u64 = 3;
    const EALREADY_INITIALIZED: u64 = 4;
    const ENOT_INITIALIZED: u64 = 5;
    const ENOT_ENOUGH_COINS: u64 = 6;
    const EINSUFFICIENT_PERMISSIONS: u64 = 7;

    // Game states
    const GAME_STATE_OPEN: u64 = 0;
    const GAME_STATE_IN_PROGRESS: u64 = 1;
    const GAME_STATE_CLOSED: u64 = 2;

    #[derive(Debug)]
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
            state: GAME_STATE_OPEN,
            winner: @0x0,
            players: vector::empty(),
        };

        simple_map::add(&mut gamestate.games, game_metadata.id, game_metadata);

        move_to(acc, gamestate);
    }

    public entry fun join_game(from: &signer, amount: u64) acquires GameState {

        let from_acc_balance:u64 = coin::balance<AptosCoin>(signer::address_of(from));
        let addr = signer::address_of(from);

        assert!(amount <= from_acc_balance, ENOT_ENOUGH_COINS);
        aptos_account::transfer(from, @poker, amount); 

        let gamestate = borrow_global_mut<GameState>(@poker); 
    }

    #[test(account = @poker)]
    fun test_address(account: &signer) {
        // 1. Get the contract's address
        let contract_address = signer::address_of(account);

        assert_is_owner(contract_address);

        // 2. Use debug::print for testing purposes
        debug::print(&contract_address);
    }

    #[test(account = @poker)] 
    fun test_join_game(account: &signer) acquires GameState {
        // Setup 
        initialize(account); // Ensure game is initialized
        let game_id = 0; // Assuming the game you want to join

        // Simulate Joining
        // join_game(account, 50); // Example amount of 50

        // Fetch and Print GameState
        let game_state = borrow_global<GameState>(@poker); 
        let game_metadata = simple_map::borrow<u64, GameMetadata>(&game_state.games, &game_id); 

        debug::print(&game_metadata.id);
        debug::print(&game_metadata.room_name);
        debug::print(&game_metadata.pot);
        debug::print(&game_metadata.state);
        debug::print(&game_metadata.winner);
        debug::print(&game_metadata.players);
    }
}