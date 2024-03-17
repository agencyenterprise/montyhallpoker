module poker::poker_manager {
    use 0x1::signer;
    use 0x1::vector;
    use 0x1::coin;
    use 0x1::aptos_coin::AptosCoin; 
    use 0x1::aptos_account;
    use 0x1::aptos_coin;
    use std::account;
    use std::option;
    use aptos_framework::randomness;
    use aptos_framework::timestamp;
    use aptos_std::fixed_point64;
    use std::simple_map::{SimpleMap,Self};
    use std::debug;
    use std::string;

    const U64_MAX: u64 = 18446744073709551615;

    /// Error codes
    const EINVALID_MOVE: u64 = 0;
    const EINSUFFICIENT_BALANCE: u64 = 1;
    const EINVALID_GAME: u64 = 2;
    const EALREADY_INITIALIZED: u64 = 3;
    const ENOT_INITIALIZED: u64 = 4;
    const EINSUFFICIENT_PERMISSIONS: u64 = 5;
    const EGAME_NOT_OPEN: u64 = 6;
    const ETABLE_IS_FULL: u64 = 7;
    const EALREADY_IN_GAME: u64 = 8;
    const EGAME_NOT_READY: u64 = 9;
    const EINSUFFICIENT_BALANCE_FOR_STAKE: u64 = 10;
    const ENOT_IN_GAME: u64 = 11;
    const EINVALID_CARD: u64 = 12;
    const ERAISE_TOO_LOW: u64 = 13;

    // Game states
    const GAMESTATE_OPEN: u64 = 0;
    const GAMESTATE_IN_PROGRESS: u64 = 1;
    const GAMESTATE_CLOSED: u64 = 2;

    // Stakes
    const LOW_STAKES: u64 = 5000000; // More or less 0.05 APT
    const MEDIUM_STAKES: u64 = 30000000; // More or less 0.3 APT
    const HIGH_STAKES: u64 = 100000000; // More or less 1 APT

    // Actions
    const FOLD: u64 = 0;
    const CHECK: u64 = 1;
    const CALL: u64 = 2;
    const RAISE: u64 = 3;
    const ALL_IN: u64 = 4;

    // Stages
    const STAGE_PREFLOP: u8 = 0;
    const STAGE_FLOP: u8 = 1;
    const STAGE_TURN: u8 = 2;
    const STAGE_RIVER: u8 = 3;
    const STAGE_SHOWDOWN: u8 = 4;

    // Status
    const STATUS_ACTIVE: u8 = 0;
    const STATUS_FOLDED: u8 = 1;
    const STATUS_ALL_IN: u8 = 2;

    // Card hierarchy
    const CARD_HIERARCHY: vector<vector<u8>> = vector[b"2", b"3", b"4", b"5", b"6", b"7", b"8", b"9", b"10", b"jack", b"queen", b"king", b"ace"];

    // Structs
    struct Card has drop, copy, store {
        cardId: u8,
        suit_string: vector<u8>,
        value_string: vector<u8>,
    }

    struct Player has drop, copy, store {
        id: address,
        hand: vector<Card>,
        status: u8,
        current_bet: u64,
    }

    struct LastRaiser has drop, copy, store {
        playerId: address,
        playerMove: u64,
    }
    
    struct GameMetadata has drop, copy, store {
        players: vector<Player>,
        deck: vector<Card>,
        community: vector<Card>,
        currentRound: u8,
        stage: u8,
        currentPlayerIndex: u8,
        continueBetting: bool,
        order: vector<Card>,
        lastRaiser: option::Option<LastRaiser>,
        seed: u8,
        id: u64,
        room_id: u64,
        stake: u64,
        pot: u64,
        starter: u8,
        state: u64,
        last_action_timestamp: u64,
        turn: address,
        current_bet: u64,
        winner: address,
    }

    struct GameState has key {
        games: SimpleMap<u64, GameMetadata>
    }

    struct UserGames has drop, copy, key {
        games: vector<u64>,
    }

    struct Evaluation has drop, copy {
        player_index: u64,
        hand_rank: u8,
        comparison_value: u8,
        hand_type: vector<u8>,
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

    fun find_player_by_address(players: &vector<Player>, addr: &address): (bool, u64) {
        let len = vector::length(players);
        let i = 0;
        while (i < len) {
            let player = vector::borrow(players, i);
            if (&player.id == addr) {
                return (true, i)
            };
            i = i + 1;
        };
        (false, 0)
    }

    // Returns stake for room_id (low first 4 rooms, medium next 4 rooms, high next 4 rooms)
    fun get_stake(room_id: u64): u64 {
        if (room_id <= 4) {
            return LOW_STAKES
        } else if (room_id <= 8) {
            return MEDIUM_STAKES
        };
        return HIGH_STAKES
    }

    // Creates empty game metadata
    fun create_game_metadata(id: u64, room_id: u64): GameMetadata {
        let random_player = randomness::u8_range(0, 4);

        GameMetadata {
            id: id,
            room_id: room_id,
            pot: 0,
            state: GAMESTATE_OPEN,
            stake: get_stake(room_id),
            turn: @0x0,
            winner: @0x0,
            players: vector::empty(),
            deck: vector::empty(),
            community: vector::empty(),
            currentRound: 0,
            stage: 0,
            currentPlayerIndex: 0,
            continueBetting: true,
            order: vector::empty(),
            lastRaiser: option::none<LastRaiser>(),
            seed: 0,
            starter: random_player,
            last_action_timestamp: 0,
            current_bet: 0,
        }
    }
    
    fun all_have_called_or_are_all_in(players: &vector<Player>, current_bet: u64): bool {
        let len = vector::length(players);
        let i = 0;
        while (i < len) {
            let player = vector::borrow(players, i);
            if (player.status == STATUS_ACTIVE && player.current_bet < current_bet) {
                return false
            };
            i = i + 1;
        };
        return true
    }

    // Initialize the game state and add the game to the global state
    fun init_module(acc: &signer) {
        let addr = signer::address_of(acc);

        assert_is_owner(addr);
        assert_uninitialized();
        
        let gamestate: GameState = GameState {
            games: simple_map::new(),
        };

        // Create a game for each room
        let i = 1;
        while (i <= 12) {
            let game_metadata = create_game_metadata(i, i);
            simple_map::add(&mut gamestate.games, game_metadata.id, game_metadata);
            i = i + 1;
        };

        move_to(acc, gamestate);
    }

    /*
    ==================================
      V I E W   F U N C T I O N S
    ==================================
    */

    #[view]
    public fun get_game_by_id(game_id: u64): GameMetadata acquires GameState {
        assert_is_initialized();
        get_game_metadata_by_id(game_id)
    }

    #[view]
    public fun get_user_by_address(addr: address): UserGames acquires UserGames {
        assert_is_initialized();
        if (exists<UserGames>(addr)) {
            *borrow_global<UserGames>(addr)
        } else {
            UserGames {
                games: vector::empty(),
            }
        }
    }

    // Returns the last game (highest id) of a specific room
    #[view]
    public fun get_last_game_by_room_id(room_id: u64): option::Option<GameMetadata> acquires GameState {
        assert_is_initialized();
        let gamestate = borrow_global<GameState>(@poker);
        let keys = simple_map::keys(&gamestate.games);
        let len = vector::length(&keys);
        let i = len - 1;
        while (i >= 0) {
            let game_metadata = simple_map::borrow<u64, GameMetadata>(&gamestate.games, vector::borrow<u64>(&keys, i));
            if (game_metadata.room_id == room_id) {
                return option::some<GameMetadata>(*game_metadata)
            };
            i = i - 1;
        };
        return option::none<GameMetadata>()
    }

    /*
    ==================================
      A C T I O N   F U N C T I O N S
    ==================================
    */

    fun start_game(game_id: u64) acquires GameState {
        let gamestate = borrow_global_mut<GameState>(@poker);
        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);
        assert!(vector::length(&game_metadata.players) == 4, EGAME_NOT_READY);
        game_metadata.starter = randomness::u8_range(0, 4);
        game_metadata.state = GAMESTATE_IN_PROGRESS;
        game_metadata.community = vector::empty();
        game_metadata.currentRound = 0;
        game_metadata.stage = STAGE_PREFLOP;
        game_metadata.currentPlayerIndex = game_metadata.starter;   
        game_metadata.turn = vector::borrow(&game_metadata.players, (game_metadata.starter as u64)).id;
        game_metadata.current_bet = 0;
        game_metadata.last_action_timestamp = timestamp::now_seconds();
        initializeDeck(game_metadata);
        dealHoleCards(game_metadata);
    }

    public fun move_to_next_stage(game_id: u64) acquires GameState {
        assert_is_initialized();

        debug::print(&string::utf8(b"Moving to next stage"));

        let gamestate = borrow_global_mut<GameState>(@poker);
        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        if (game_metadata.state == GAMESTATE_CLOSED) {
            return
        };

        if (game_metadata.stage == STAGE_PREFLOP) {
            dealCommunityCards(game_metadata, 3);
        } else if (game_metadata.stage == STAGE_FLOP) {
            dealCommunityCards(game_metadata, 1);
        } else if (game_metadata.stage == STAGE_TURN) {
            dealCommunityCards(game_metadata, 1);
        };

        game_metadata.stage = (game_metadata.stage + 1) % 5;
        debug::print(&string::utf8(b"Stage: "));
        debug::print(&game_metadata.stage);
        game_metadata.currentPlayerIndex = game_metadata.starter;
        game_metadata.turn = vector::borrow(&game_metadata.players, (game_metadata.starter as u64)).id;
        game_metadata.current_bet = 0;

        // Reset current bets
        let i = 0;
        while (i < vector::length(&game_metadata.players)) {
            let player = vector::borrow_mut(&mut game_metadata.players, i);
            player.current_bet = 0;
            i = i + 1;
        };

        game_metadata.lastRaiser = option::none<LastRaiser>();
    }

    /* 
    =================================
      E N T R Y   F U N C T I O N S
    =================================
    */

    public entry fun create_game(acc: &signer, room_id: u64) acquires GameState {
        let addr = signer::address_of(acc);
        assert_is_initialized();

        assert!(room_id > 0 && room_id <= 12, EINVALID_GAME);
        // check if room_id's last game is closed
        let last_game = get_last_game_by_room_id(room_id);
        if (option::is_some(&last_game)) {
            let game_metadata = option::borrow(&last_game);
            assert!(game_metadata.state == GAMESTATE_CLOSED, EINVALID_GAME);
        };

        let gamestate = borrow_global_mut<GameState>(@poker);

        // Add a new game to the global state
        let game_metadata = create_game_metadata(vector::length<u64>(&simple_map::keys(&gamestate.games)) + 1, room_id);

        simple_map::add(&mut gamestate.games, game_metadata.id, game_metadata);
    }

    // When user joins and places an ante
    public entry fun join_game(from: &signer, game_id: u64, amount: u64) acquires GameState, UserGames {
        let from_acc_balance:u64 = coin::balance<AptosCoin>(signer::address_of(from));
        let addr = signer::address_of(from);

        assert!(amount <= from_acc_balance, EINSUFFICIENT_BALANCE);
        
        assert_account_is_not_in_open_game(addr);

        let gamestate = borrow_global_mut<GameState>(@poker);

        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        assert!(vector::length(&game_metadata.players) < 4, ETABLE_IS_FULL);

        assert!(game_metadata.state == GAMESTATE_OPEN, EGAME_NOT_OPEN);

        assert!(amount >= game_metadata.stake, EINSUFFICIENT_BALANCE_FOR_STAKE);
        
        aptos_account::transfer(from, @poker, amount); 

        vector::push_back(&mut game_metadata.players, Player{id: addr, hand: vector::empty(), status: STATUS_ACTIVE, current_bet: 0});
        game_metadata.pot = game_metadata.pot + amount;

        if (!exists<UserGames>(addr)) {
            move_to(from, UserGames {
                games: vector[game_id],
            })
        } else {
            let user_games = borrow_global_mut<UserGames>(addr);
            vector::push_back(&mut user_games.games, game_id);
        };

        if (vector::length(&game_metadata.players) == 4) {
            start_game(game_id);
        };
    }

    public entry fun populate_card_values(from: &signer, game_id: u64, suit_strings: vector<string::String>, value_strings: vector<string::String>) acquires GameState {
        assert_is_initialized();

        let gamestate = borrow_global_mut<GameState>(@poker);
        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        let i = 0;
        while (i < 52) {
            let card = vector::borrow_mut(&mut game_metadata.deck, i);
            card.suit_string = *string::bytes(vector::borrow(&suit_strings, i));
            card.value_string = *string::bytes(vector::borrow(&value_strings, i));
            i = i + 1;
        };

        // Find winner and end game
        let winner = get_game_winner(game_metadata);
        let winner_index = winner.player_index;
        let player = vector::borrow(&game_metadata.players, winner_index);

        game_metadata.winner = player.id;
        game_metadata.state = GAMESTATE_CLOSED;

        let winner_addr = vector::borrow(&game_metadata.players, winner.player_index).id;
        aptos_account::transfer(from, winner_addr, game_metadata.pot);
    }

    public entry fun leave_game(from: &signer, game_id: u64) acquires GameState, UserGames {
        let addr = signer::address_of(from);
        assert_is_initialized();

        let gamestate = borrow_global<GameState>(@poker);
        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow(&gamestate.games, &game_id);

        let (is_player_in_game, player_index) = find_player_by_address(&game_metadata.players, &addr);
        assert!(is_player_in_game, ENOT_IN_GAME);

        if (game_metadata.state == GAMESTATE_IN_PROGRESS) {
            perform_action(from, game_id, FOLD, 0);
        };
        
        {
            let gamestate = borrow_global_mut<GameState>(@poker);
            let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);
            vector::remove(&mut game_metadata.players, player_index);
        };

        if (exists<UserGames>(addr)) {
            let user_games = borrow_global_mut<UserGames>(addr);
            (is_player_in_game, player_index) = vector::index_of(&user_games.games, &game_id);
            if (is_player_in_game) {
                let game_index = player_index;
                vector::remove(&mut user_games.games, game_index);
            }
        }
    }

    public entry fun perform_action(from: &signer, game_id: u64, action: u64, amount: u64) acquires GameState {
        let addr = signer::address_of(from);
        assert_is_initialized();

        let gamestate = borrow_global_mut<GameState>(@poker);
        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        let (is_player_in_game, player_index) = find_player_by_address(&game_metadata.players, &addr);
        assert!(is_player_in_game, ENOT_IN_GAME);

        let player = vector::borrow_mut(&mut game_metadata.players, player_index);

        debug::print(&string::utf8(b"Player index: "));
        debug::print(&player_index);
        debug::print(&string::utf8(b"Action: "));
        debug::print(&action);
        debug::print(&string::utf8(b"Amount: "));
        debug::print(&amount);

        debug::print(&string::utf8(b"Current bet: "));
        debug::print(&game_metadata.starter);

        assert!(game_metadata.turn == addr, EINSUFFICIENT_PERMISSIONS);

        // Check if player has enough balance to perform the action
        if (amount > 0) {
            assert!(amount <= coin::balance<AptosCoin>(addr), EINSUFFICIENT_BALANCE);
        };

        if (action == FOLD) {
            player.status = STATUS_FOLDED;
        } else if (action == CHECK) {
            assert!(game_metadata.current_bet == 0, EINVALID_MOVE);
        } else if (action == CALL) {
            // assert that attempted bet is equal to the current bet and it's not 0
            assert!(amount > 0, EINVALID_MOVE);
            assert!(game_metadata.current_bet == amount, EINVALID_MOVE);
            let diff = game_metadata.current_bet - player.current_bet;
            assert!(diff <= amount, EINVALID_MOVE);
            player.current_bet = player.current_bet + diff;
            game_metadata.pot = game_metadata.pot + diff;
        } else if (action == RAISE) {
            debug::print(&string::utf8(b"Amount has to be: "));
            debug::print(&(game_metadata.current_bet + game_metadata.stake));
            // Raise has to be at least current bet + stake
            assert!(amount >= game_metadata.current_bet + game_metadata.stake, ERAISE_TOO_LOW);
            player.current_bet = player.current_bet + amount;
            game_metadata.pot = game_metadata.pot + amount;
            game_metadata.current_bet = amount;
            game_metadata.lastRaiser = option::some<LastRaiser>(LastRaiser{playerId: addr, playerMove: action});
            debug::print(&string::utf8(b"JUST SET Last raiser to: "));
            debug::print(&game_metadata.lastRaiser);
        } else if (action == ALL_IN) {
            player.current_bet = player.current_bet + amount;
            game_metadata.pot = game_metadata.pot + amount;
            game_metadata.current_bet = amount;
            player.status = STATUS_ALL_IN;
        };

        game_metadata.last_action_timestamp = timestamp::now_seconds();

        let nextPlayer = vector::borrow(&game_metadata.players, (player_index + 1) % vector::length(&game_metadata.players));
        game_metadata.turn = nextPlayer.id;
        game_metadata.currentPlayerIndex = ((player_index + 1) % vector::length(&game_metadata.players) as u8);
        
        let activePlayers = 0;
        let lastActivePlayerIndex = 0;
        let i = 0;
        while (i < vector::length(&game_metadata.players)) {
            let player = vector::borrow(&game_metadata.players, i);
            if (player.status == STATUS_ACTIVE && timestamp::now_seconds() - game_metadata.last_action_timestamp < 120) {
                activePlayers = activePlayers + 1;
                lastActivePlayerIndex = i;
            };
            i = i + 1;
        };

        if (activePlayers == 1) {
            game_metadata.winner = vector::borrow(&game_metadata.players, (lastActivePlayerIndex as u64)).id;
            game_metadata.state = GAMESTATE_CLOSED;
        } else if (activePlayers == 0) {
            game_metadata.state = GAMESTATE_CLOSED;
        };

        let should_move_to_next_stage = false;
        
        debug::print(&string::utf8(b"Current player index: "));
        debug::print(&game_metadata.currentPlayerIndex);
        debug::print(&string::utf8(b"Current bet: "));
        debug::print(&game_metadata.current_bet);
        debug::print(&string::utf8(b"Starter: "));
        debug::print(&game_metadata.starter);
        // If it's the starter's turn and all players have called or are all in, move to next stage
        if (game_metadata.currentPlayerIndex == game_metadata.starter) {
            if (all_have_called_or_are_all_in(&game_metadata.players, game_metadata.current_bet)) {
                should_move_to_next_stage = true;
            };
        };

        // If it's the turn of the last raiser and all players have called or are all in, move to next stage
        debug::print(&string::utf8(b"Last raiser: "));
        if (option::is_some(&game_metadata.lastRaiser)) {
            let lastRaiser = option::borrow(&game_metadata.lastRaiser);
            debug::print(lastRaiser);
            // lastRaiser will be next player
            let addrNextPlayer = vector::borrow(&game_metadata.players, (game_metadata.currentPlayerIndex as u64)).id;
            if (lastRaiser.playerId == addrNextPlayer && all_have_called_or_are_all_in(&game_metadata.players, game_metadata.current_bet)) {
                should_move_to_next_stage = true;
            };
        } else {
            debug::print(&string::utf8(b"No last raiser"));
        };

        debug::print(&string::utf8(b"Should move to next stage: "));
        debug::print(&should_move_to_next_stage);
        if (should_move_to_next_stage) {
            move_to_next_stage(game_id);
        };
    }

    // Skip player's turn if they are inactive (30 seconds without action), anyone can call this function
    public entry fun skip_inactive_player(game_id: u64) acquires GameState {
        assert_is_initialized();

        let gamestate = borrow_global_mut<GameState>(@poker);
        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        assert!(game_metadata.state == GAMESTATE_IN_PROGRESS, EINVALID_GAME);

        let time_diff = timestamp::now_seconds() - game_metadata.last_action_timestamp;
        if (time_diff > 30) {
            let nextPlayer = vector::borrow(&game_metadata.players, ((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players));
            game_metadata.turn = nextPlayer.id;
            game_metadata.currentPlayerIndex = (((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players) as u8);
        }
    }

    fun initializeDeck(game: &mut GameMetadata) {
        
        // Gamedeck will be a vector of 52 cards, with ids from 0 to 51
        // value_string and suit_string will not be used for now, only when evaluating winner
        let i = 0;
        while (i < 52) {
            vector::push_back(&mut game.deck, Card {
                    cardId: i,
                    suit_string: b"",
                    value_string: b""
                });
            i = i + 1;
        };

        game.seed = randomness::u8_range(0, 51);
    }

    fun dealHoleCards(game_metadata: &mut GameMetadata) {
        let i = 0;
        let players_len = vector::length(&game_metadata.players);
        while (i < players_len) {
            let player = vector::borrow_mut(&mut game_metadata.players, i);
            vector::push_back(&mut player.hand, vector::pop_back(&mut game_metadata.deck));
            vector::push_back(&mut player.hand, vector::pop_back(&mut game_metadata.deck));
            i = i + 1;
        };
    }


    fun dealCommunityCards(game_metadata: &mut GameMetadata, number: u8) {
        let deck_size = (vector::length(&game_metadata.deck) as u8);
        assert!(deck_size >= number, EINVALID_MOVE);

        let i: u8 = 0;
        while (i < number) {
            let index = (i + game_metadata.seed) % (deck_size as u8);
            let card = vector::remove(&mut game_metadata.deck, (index as u64));
            vector::push_back(&mut game_metadata.community, card);
            i = i + 1;
        }
    }

    fun evaluateHandDetails(cards: &vector<Card>): (vector<u8>, u8, u8) {
        let straight: bool = false;
        let handType: vector<u8> = b"High Card";
        let _flush: bool = false;
        let handRank: u8 = 1;
        let highestValue: u8 = 0;
        let pairs: u8 = 0;
        let threeOfAKind: u8 = 0;
        let fourOfAKind: u8 = 0;
        let suits = simple_map::new<vector<u8>, u8>();
        let values = simple_map::new<u8, u8>();
        let i = 0;

        while (i < vector::length(cards)) {
            let card = vector::borrow(cards, i);
            let suit = card.suit_string;
            let value: vector<u8> = card.value_string;

            if (!simple_map::contains_key<vector<u8>, u8>(&suits, &suit)) {
                simple_map::upsert(&mut suits, copy suit, 1);
            } else {
                let suitCount = simple_map::borrow<vector<u8>, u8>(&suits, &suit);
                simple_map::upsert(&mut suits, copy suit, *suitCount + 1);
            };
            
            let (hasIndex, valueIndex) = vector::index_of<vector<u8>>(&CARD_HIERARCHY, &value);

            if (!hasIndex) {
                debug::print(&string::utf8(b"Invalid card: "));
                debug::print(&value);
                debug::print(&string::utf8(b"Cards: "));
                debug::print(cards);
            };

            assert!(hasIndex, EINVALID_CARD);

            if (!simple_map::contains_key<u8, u8>(&values, &(valueIndex as u8))) {
                simple_map::upsert(&mut values, (valueIndex as u8), 1);
            } else {
                let valueCount = simple_map::borrow<u8, u8>(&values, &(valueIndex as u8));
                simple_map::upsert(&mut values, (valueIndex as u8), *valueCount + 1);
            };
            if ((valueIndex as u8) > highestValue) {
                highestValue = (valueIndex as u8);
            };
            i = i + 1;
        };

        _flush = vector::any<u8>(&simple_map::values<vector<u8>, u8>(&suits), |count| {
            *count >= 5 
        });

        let consecutiveCount: u8 = 0;
        let lastValue: u8 = 0;

        for (idx in 0..13) {
            if (simple_map::contains_key<u8, u8>(&values, &idx)) {
                if (consecutiveCount == 0) {
                    
                    consecutiveCount = 1;
                    lastValue = idx;
                } else if (idx == lastValue + 1) {
                    
                    consecutiveCount = consecutiveCount + 1;
                    lastValue = idx;

                    if (consecutiveCount >= 5) {
                        straight = true;
                        break
                    };
                } else {
                    consecutiveCount = 1;
                    lastValue = idx;
                };
            };

            if (idx == 3 && consecutiveCount == 4 && simple_map::contains_key<u8, u8>(&values, &12)) {
                straight = true;
                break
            };
        };
        
        vector::for_each<u8>(simple_map::values<u8, u8>(&values), |value| {
            if (value == 2) {
                pairs = pairs + 1;
            } else if (value == 3) {
                threeOfAKind = threeOfAKind + 1;
            } else if (value == 4) {
                fourOfAKind = fourOfAKind + 1;
            }
        });
        
        if (_flush && straight) {
            handType = b"Straight Flush";
            handRank = 9;
        } else if (fourOfAKind > 0) {
            handType = b"Four of a Kind";
            handRank = 8;
        } else if (threeOfAKind > 0 && pairs > 0) {
            handType = b"Full House";
            handRank = 7;
        } else if (_flush) {
            handType = b"Flush";
            handRank = 6;
        } else if (straight) {
            handType = b"Straight";
            handRank = 5;
        } else if (threeOfAKind > 0) {
            handType = b"Three of a Kind";
            handRank = 4;
        } else if (pairs == 2) {
            handType = b"Two Pair";
            handRank = 3;
        } else if (pairs == 1) {
            handType = b"One Pair";
            handRank = 2;
        };

        (handType, handRank, highestValue)
    }

    fun evaluateHand(communityCards: &vector<Card>, playerCards: &vector<Card>): (vector<u8>, u8, u8) {
        let newCards = vector::empty<Card>();
        vector::append<Card>(&mut newCards, *communityCards);
        vector::append<Card>(&mut newCards, *playerCards);
        evaluateHandDetails(&newCards)
    }

    fun get_game_winner(game_metadata: &mut GameMetadata): Evaluation {
        let players_len = vector::length(&game_metadata.players);
        let evaluations: vector<Evaluation> = vector::empty();

        let i = 0;
        while (i < players_len) {
            let player = vector::borrow(&game_metadata.players, i);
            if (player.status == STATUS_ACTIVE) {
                let (hand_type, hand_rank, highest_value) = evaluateHand(&game_metadata.community, &player.hand);
                let evaluation = Evaluation {
                    player_index: i,
                    hand_rank: hand_rank,
                    comparison_value: highest_value,
                    hand_type: hand_type,
                };
                vector::push_back(&mut evaluations, evaluation);
            };
            i = i + 1;
        };


        assert!(vector::length(&evaluations) > 0, EINVALID_GAME);

        let winner_index: u64 = vector::borrow(&evaluations, 0).player_index;
        let highest_rank: u8 = vector::borrow(&evaluations, 0).hand_rank;
        let highest_comparison_value: u8 = vector::borrow(&evaluations, 0).comparison_value;
        let highest_hand_type: vector<u8> = vector::borrow(&evaluations, 0).hand_type;

        let j = 1;
        while (j < vector::length(&evaluations)) {
            let evaluation = vector::borrow(&evaluations, j);
            if (evaluation.hand_rank > highest_rank || (evaluation.hand_rank == highest_rank && evaluation.comparison_value > highest_comparison_value)) {
                winner_index = evaluation.player_index;
                highest_rank = evaluation.hand_rank;
                highest_comparison_value = evaluation.comparison_value;
                highest_hand_type = evaluation.hand_type;
            };
            j = j + 1;
        };

        Evaluation {
            player_index: winner_index,
            hand_rank: highest_rank,
            comparison_value: highest_comparison_value,
            hand_type: highest_hand_type,
        }
    }

    /*
    =================================
      T E S T   F U N C T I O N S
    =================================
    */

    #[test(admin = @poker, aptos_framework = @0x1, account1 = @0x3, account2 = @0x4, account3 = @0x5, account4 = @0x6)]
    fun test_join_game(account1: &signer, account2: &signer, account3: &signer, account4: &signer,
    admin: &signer, aptos_framework: &signer)
    acquires GameState, UserGames {
        // Setup 

        randomness::initialize_for_testing(aptos_framework);
        randomness::set_seed(x"0000000000000000000000000000000000000000000000000000000000000000");

        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test_secs(1710563686);

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

        {
            let pre_game = get_game_metadata_by_id(game_id);
            assert!(pre_game.state == GAMESTATE_OPEN, 0);
            assert!(vector::length(&pre_game.players) == 0, 0);
            assert!(vector::length(&pre_game.community) == 0, 0);
        };

        // Simulate Joining
        join_game(account1, 1, 5000000);
        join_game(account2, 1, 6000000);
        join_game(account3, 1, 7000000);
        join_game(account4, 1, 8000000);

        let game_metadata = get_game_metadata_by_id(game_id);

        //debug::print(&game_metadata);

        // Make sure the game is in the global state and has the correct number of players
        assert!(game_metadata.id == copy game_id, EINVALID_GAME);
        assert!(game_metadata.state == GAMESTATE_IN_PROGRESS, EINVALID_GAME);
        assert!(game_metadata.stage == STAGE_PREFLOP, EINVALID_GAME);
        assert!(vector::length(&game_metadata.players) == 4, EINVALID_GAME);
        assert!(vector::length(&game_metadata.community) == 0, EINVALID_GAME);

        {
            // Assert each player has 2 cards
            let player1 = vector::borrow(&game_metadata.players, 0);
            let player2 = vector::borrow(&game_metadata.players, 1);
            let player3 = vector::borrow(&game_metadata.players, 2);
            let player4 = vector::borrow(&game_metadata.players, 3);
            assert!(vector::length(&player1.hand) == 2, EINVALID_GAME);
            assert!(vector::length(&player2.hand) == 2, EINVALID_GAME);
            assert!(vector::length(&player3.hand) == 2, EINVALID_GAME);
            assert!(vector::length(&player4.hand) == 2, EINVALID_GAME);
        };

        // Actions
        {
            perform_action(account3, game_id, RAISE, 8000000);
            perform_action(account4, game_id, CALL, 8000000);
            perform_action(account1, game_id, CALL, 8000000);
            perform_action(account2, game_id, CALL, 8000000);

            let game_metadata = get_game_metadata_by_id(game_id);

            assert!(game_metadata.stage == STAGE_FLOP, EINVALID_GAME);
        };

        {
            let gamestate = borrow_global_mut<GameState>(@poker);
            let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

            let num_players = vector::length(&game_metadata.players);
            let i = 0;
            while (i < num_players) {
                let player = vector::borrow_mut(&mut game_metadata.players, i);

                // Instead of a match statement, use if-else to update player hands based on the index
                if (i == 0) {
                    player.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"3"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"4"}];
                } else if (i == 1) {
                    player.hand = vector[Card{cardId: 2, suit_string: b"clubs", value_string: b"7"}, Card{cardId: 3, suit_string: b"spades", value_string: b"2"}];
                } else if (i == 2) {
                    player.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 1, suit_string: b"clubs", value_string: b"10"}];
                } else if (i == 3) {
                    player.hand = vector[Card{cardId: 2, suit_string: b"spades", value_string: b"3"}, Card{cardId: 3, suit_string: b"spades", value_string: b"jack"}];
                };
                // Add more conditions as necessary for other players

                i = i + 1;
            };
            
        };

        {
            perform_action(account3, game_id, RAISE, 8000000);
            perform_action(account4, game_id, RAISE, 13000000);
            perform_action(account1, game_id, CALL, 13000000);
            perform_action(account2, game_id, RAISE, 18000000);
            perform_action(account3, game_id, CALL, 18000000);
            perform_action(account4, game_id, CALL, 18000000);
            perform_action(account1, game_id, CALL, 18000000);

            let game_metadata = get_game_metadata_by_id(game_id);

            assert!(game_metadata.stage == STAGE_TURN, EINVALID_GAME);
            assert!(vector::length(&game_metadata.community) == 4, EINVALID_GAME);
        };

        {
            perform_action(account3, game_id, CHECK, 0);
            perform_action(account4, game_id, CHECK, 0);
            perform_action(account1, game_id, CHECK, 0);
            perform_action(account2, game_id, RAISE, 10000000);
            perform_action(account3, game_id, CALL, 10000000);
            perform_action(account4, game_id, CALL, 10000000);
            perform_action(account1, game_id, CALL, 10000000);

            let game_metadata = get_game_metadata_by_id(game_id);

            assert!(game_metadata.stage == STAGE_RIVER, EINVALID_GAME);
            assert!(vector::length(&game_metadata.community) == 5, EINVALID_GAME);
        };

        {
            perform_action(account3, game_id, RAISE, 5000000);
            perform_action(account4, game_id, RAISE, 10000000);
            perform_action(account1, game_id, CALL, 10000000);
            perform_action(account2, game_id, CALL, 10000000);
            perform_action(account3, game_id, CALL, 10000000);

            let game_metadata = get_game_metadata_by_id(game_id);

            assert!(game_metadata.stage == STAGE_SHOWDOWN, EINVALID_GAME);
            assert!(vector::length(&game_metadata.community) == 5, EINVALID_GAME);

            game_metadata.community = vector[
                Card{cardId: 0, suit_string: b"hearts", value_string: b"9"},
                Card{cardId: 1, suit_string: b"diamonds", value_string: b"4"},
                Card{cardId: 2, suit_string: b"clubs", value_string: b"7"},
                Card{cardId: 3, suit_string: b"spades", value_string: b"2"},
                Card{cardId: 4, suit_string: b"hearts", value_string: b"8"},
            ];
            
            let winner = get_game_winner(&mut game_metadata);
            let winner_index = winner.player_index;

            assert!(winner_index == 1, EINVALID_GAME);
        };

        let user1_games = borrow_global<UserGames>(signer::address_of(account1));
        let user2_games = borrow_global<UserGames>(signer::address_of(account2));
        let user3_games = borrow_global<UserGames>(signer::address_of(account3));
        let user4_games = borrow_global<UserGames>(signer::address_of(account4));

        // Make sure the users have the game in their list of games
        assert!(vector::length(&user1_games.games) == 1, EINVALID_GAME);
        assert!(vector::length(&user2_games.games) == 1, EINVALID_GAME);
        assert!(vector::length(&user3_games.games) == 1, EINVALID_GAME);
        assert!(vector::length(&user4_games.games) == 1, EINVALID_GAME);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test_only]
    fun create_player(id: address, hand: vector<Card>): Player {
        let player = Player {
            id: id,
            hand: hand,
            status: 0,
            current_bet: 0,
        };
        player
    }

    // Tests all poker hands (from high card to straight flush)
    #[test(fx = @aptos_framework, admin = @poker)]
    fun test_poker_hands(fx: &signer) {

        randomness::initialize_for_testing(fx);
        randomness::set_seed(x"0000000000000000000000000000000000000000000000000000000000000000");

        let game_metadata = create_game_metadata(1, 1);

        // Evaluate all hands only take into consideration the value_string and suit_string of the cards, 
        // disregarding the suit and value fields

        // High card

        vector::append(&mut game_metadata.community, 
            vector[
            Card{cardId: 0, suit_string: b"spades", value_string: b"2"},
            Card{cardId: 1, suit_string: b"diamonds", value_string: b"10"},
            Card{cardId: 2, suit_string: b"clubs", value_string: b"7"}
            ]
        );
        
        let player1 = create_player(@0x1, vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"3"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"4"}]);
        let player2 = create_player(@0x2, vector[Card{cardId: 2, suit_string: b"clubs", value_string: b"5"}, Card{cardId: 3, suit_string: b"spades", value_string: b"6"}]);
        let player3 = create_player(@0x3, vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"9"}]);
        let player4 = create_player(@0x4, vector[Card{cardId: 2, suit_string: b"spades", value_string: b"3"}, Card{cardId: 3, suit_string: b"spades", value_string: b"jack"}]);

        game_metadata.players = vector[player1, player2, player3, player4];
        
        let winner = get_game_winner(&mut game_metadata);

        assert!(winner.player_index == 3, EINVALID_GAME);

        // One pair

        game_metadata.community = vector::empty();
        vector::append(&mut game_metadata.community, 
            vector[
            Card{cardId: 0, suit_string: b"spades", value_string: b"2"},
            Card{cardId: 1, suit_string: b"diamonds", value_string: b"10"},
            Card{cardId: 2, suit_string: b"clubs", value_string: b"7"},
            ]
        );

        player1.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"3"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"4"}];
        player2.hand = vector[Card{cardId: 2, suit_string: b"clubs", value_string: b"5"}, Card{cardId: 3, suit_string: b"spades", value_string: b"6"}];
        player3.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 1, suit_string: b"clubs", value_string: b"10"}];
        player4.hand = vector[Card{cardId: 2, suit_string: b"spades", value_string: b"3"}, Card{cardId: 3, suit_string: b"spades", value_string: b"jack"}];

        game_metadata.players = vector[player1, player2, player3, player4];

        winner = get_game_winner(&mut game_metadata);

        assert!(winner.player_index == 2, EINVALID_GAME);

        // Two pair

        game_metadata.community = vector::empty();

        vector::append(&mut game_metadata.community, 
            vector[
            Card{cardId: 0, suit_string: b"spades", value_string: b"2"},
            Card{cardId: 1, suit_string: b"diamonds", value_string: b"10"},
            Card{cardId: 2, suit_string: b"clubs", value_string: b"7"},
            ]
        );

        player1.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"3"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"4"}];
        player2.hand = vector[Card{cardId: 2, suit_string: b"clubs", value_string: b"7"}, Card{cardId: 3, suit_string: b"spades", value_string: b"2"}];
        player3.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 1, suit_string: b"clubs", value_string: b"10"}];
        player4.hand = vector[Card{cardId: 2, suit_string: b"spades", value_string: b"3"}, Card{cardId: 3, suit_string: b"spades", value_string: b"jack"}];

        game_metadata.players = vector[player1, player2, player3, player4];

        winner = get_game_winner(&mut game_metadata);

        assert!(winner.player_index == 1, EINVALID_GAME);

        // Three of a kind

        game_metadata.community = vector::empty();

        vector::append(&mut game_metadata.community, 
            vector[
            Card{cardId: 0, suit_string: b"spades", value_string: b"2"},
            Card{cardId: 1, suit_string: b"hearts", value_string: b"10"},
            Card{cardId: 2, suit_string: b"clubs", value_string: b"7"},
            ]
        );

        player1.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"3"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"4"}];
        player2.hand = vector[Card{cardId: 2, suit_string: b"clubs", value_string: b"7"}, Card{cardId: 3, suit_string: b"spades", value_string: b"2"}];
        player3.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 1, suit_string: b"clubs", value_string: b"10"}];
        player4.hand = vector[Card{cardId: 2, suit_string: b"spades", value_string: b"7"}, Card{cardId: 3, suit_string: b"hearts", value_string: b"7"}];

        game_metadata.players = vector[player1, player2, player3, player4];
        
        winner = get_game_winner(&mut game_metadata);

        assert!(winner.player_index == 3, EINVALID_GAME);

        // Straight

        game_metadata.community = vector::empty();

        vector::append(&mut game_metadata.community, 
            vector[
            Card{cardId: 0, suit_string: b"spades", value_string: b"2"},
            Card{cardId: 1, suit_string: b"hearts", value_string: b"5"},
            Card{cardId: 2, suit_string: b"clubs", value_string: b"4"},
            ]
        );

        player1.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"ace"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"3"}];
        player2.hand = vector[Card{cardId: 2, suit_string: b"clubs", value_string: b"5"}, Card{cardId: 3, suit_string: b"spades", value_string: b"4"}];
        player3.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 1, suit_string: b"clubs", value_string: b"9"}];
        player4.hand = vector[Card{cardId: 2, suit_string: b"spades", value_string: b"3"}, Card{cardId: 3, suit_string: b"spades", value_string: b"jack"}];

        game_metadata.players = vector[player1, player2, player3, player4];

        winner = get_game_winner(&mut game_metadata);

        assert!(winner.player_index == 0, EINVALID_GAME);

        // Flush

        game_metadata.community = vector::empty();

        vector::append(&mut game_metadata.community, 
            vector[
            Card{cardId: 0, suit_string: b"spades", value_string: b"2"},
            Card{cardId: 1, suit_string: b"hearts", value_string: b"5"},
            Card{cardId: 2, suit_string: b"hearts", value_string: b"4"},
            Card{cardId: 2, suit_string: b"spades", value_string: b"queen"},
            Card{cardId: 2, suit_string: b"hearts", value_string: b"king"},
            ]
        );

        player1.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"ace"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"3"}];
        player2.hand = vector[Card{cardId: 2, suit_string: b"clubs", value_string: b"5"}, Card{cardId: 3, suit_string: b"spades", value_string: b"4"}];
        player3.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 1, suit_string: b"hearts", value_string: b"9"}];
        player4.hand = vector[Card{cardId: 2, suit_string: b"spades", value_string: b"3"}, Card{cardId: 3, suit_string: b"spades", value_string: b"jack"}];

        game_metadata.players = vector[player1, player2, player3, player4];


        winner = get_game_winner(&mut game_metadata);

        assert!(winner.player_index == 2, EINVALID_GAME);

        // Full house

        game_metadata.community = vector::empty();

        vector::append(&mut game_metadata.community, 
            vector[
            Card{cardId: 0, suit_string: b"spades", value_string: b"ace"},
            Card{cardId: 1, suit_string: b"hearts", value_string: b"5"},
            Card{cardId: 2, suit_string: b"hearts", value_string: b"4"},
            Card{cardId: 2, suit_string: b"spades", value_string: b"queen"},
            Card{cardId: 2, suit_string: b"hearts", value_string: b"queen"},
            ]
        );

        player1.hand = vector[Card{cardId: 0, suit_string: b"clubs", value_string: b"ace"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"ace"}];
        player2.hand = vector[Card{cardId: 2, suit_string: b"clubs", value_string: b"5"}, Card{cardId: 3, suit_string: b"spades", value_string: b"4"}];
        player3.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 1, suit_string: b"hearts", value_string: b"9"}];
        player4.hand = vector[Card{cardId: 2, suit_string: b"spades", value_string: b"3"}, Card{cardId: 3, suit_string: b"spades", value_string: b"jack"}];

        game_metadata.players = vector[player1, player2, player3, player4];


        winner = get_game_winner(&mut game_metadata);

        assert!(winner.player_index == 0, EINVALID_GAME);

        // Four of a kind
        
        game_metadata.community = vector::empty();

        vector::append(&mut game_metadata.community, 
            vector[
            Card{cardId: 0, suit_string: b"spades", value_string: b"ace"},
            Card{cardId: 1, suit_string: b"hearts", value_string: b"5"},
            Card{cardId: 2, suit_string: b"hearts", value_string: b"4"},
            Card{cardId: 2, suit_string: b"spades", value_string: b"queen"},
            Card{cardId: 2, suit_string: b"hearts", value_string: b"queen"},
            ]
        );

        player1.hand = vector[Card{cardId: 0, suit_string: b"clubs", value_string: b"ace"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"ace"}];
        player2.hand = vector[Card{cardId: 2, suit_string: b"clubs", value_string: b"queen"}, Card{cardId: 3, suit_string: b"diamonds", value_string: b"queen"}];
        player3.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 1, suit_string: b"hearts", value_string: b"9"}];
        player4.hand = vector[Card{cardId: 2, suit_string: b"spades", value_string: b"3"}, Card{cardId: 3, suit_string: b"spades", value_string: b"jack"}];

        game_metadata.players = vector[player1, player2, player3, player4];

        winner = get_game_winner(&mut game_metadata);

        assert!(winner.player_index == 1, EINVALID_GAME);

        // Straight flush

        game_metadata.community = vector::empty();

        vector::append(&mut game_metadata.community, 
            vector[
            Card{cardId: 0, suit_string: b"diamonds", value_string: b"6"},
            Card{cardId: 1, suit_string: b"spades", value_string: b"4"},
            Card{cardId: 2, suit_string: b"spades", value_string: b"6"},
            Card{cardId: 2, suit_string: b"spades", value_string: b"5"},
            Card{cardId: 2, suit_string: b"spades", value_string: b"3"},
            ]
        );

        player1.hand = vector[Card{cardId: 0, suit_string: b"spades", value_string: b"ace"}, Card{cardId: 1, suit_string: b"spades", value_string: b"king"}];
        player2.hand = vector[Card{cardId: 2, suit_string: b"spades", value_string: b"queen"}, Card{cardId: 3, suit_string: b"spades", value_string: b"jack"}];
        player3.hand = vector[Card{cardId: 0, suit_string: b"spades", value_string: b"10"}, Card{cardId: 1, suit_string: b"spades", value_string: b"9"}];
        player4.hand = vector[Card{cardId: 2, suit_string: b"spades", value_string: b"8"}, Card{cardId: 3, suit_string: b"spades", value_string: b"7"}];

        game_metadata.players = vector[player1, player2, player3, player4];

        winner = get_game_winner(&mut game_metadata);

        assert!(winner.player_index == 3, EINVALID_GAME);
    }
}