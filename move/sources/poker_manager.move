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
    const ESTAKE_MISMATCH: u64 = 10;
    const ENOT_IN_GAME: u64 = 11;
    const EINVALID_CARD: u64 = 12;
    const ERAISE_TOO_LOW: u64 = 13;
    const ERAISE_TOO_HIGH: u64 = 14;
    const EINVALID_STAGE: u64 = 15;

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

    // Fees
    const HOUSE_FEE: u64 = 1; // 1% of the pot

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
        checked: bool,
    }

    struct LastRaiser has drop, copy, store {
        playerId: address,
        playerMove: u64,
    }

    struct SidePot has drop, copy, store {
        amount: u64,
        eligible_players: vector<address>,
    }
    
    struct GameMetadata has drop, copy, store {
        players: vector<Player>,
        deck: vector<Card>,
        community: vector<Card>,
        currentRound: u8,
        stage: u8,
        currentPlayerIndex: u8,
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
        winners: vector<address>,
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
        bestCombinationHighestValue: simple_map::SimpleMap<u8, vector<u8>>,
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
            winners: vector::empty(),
            players: vector::empty(),
            deck: vector::empty(),
            community: vector::empty(),
            currentRound: 0,
            stage: 0,
            currentPlayerIndex: 0,
            lastRaiser: option::none<LastRaiser>(),
            seed: 0,
            starter: random_player,
            last_action_timestamp: 0,
            current_bet: 0,
        }
    }

    fun get_max_raise_for(addr: address, players: &vector<Player>): u64 {
        let min_balance: u64 = U64_MAX;

        let i = 0;
        while (i < vector::length(players)) {
            let player = vector::borrow(players, i);
            // Skip folded players
            if (player.status == STATUS_ACTIVE && player.id != addr) {
                let player_balance = coin::balance<AptosCoin>(player.id);
                if (player_balance < min_balance) {
                    min_balance = player_balance;
                };
            };
            i = i + 1;
        };
        min_balance
    }
    
    fun all_have_called_or_checked(players: &vector<Player>, current_bet: u64): bool {
        let len = vector::length(players);
        let i = 0;
        while (i < len) {
            let player = vector::borrow(players, i);
            if (player.status == STATUS_ACTIVE && player.current_bet == 0 && current_bet == 0 && player.checked == false) {
                return false
            };
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
        initialize_deck(game_metadata);
        deal_hole_cards(game_metadata);
    }

    public fun create_game(room_id: u64) acquires GameState {
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

        debug::print(&string::utf8(b"Game created: "));
        debug::print(&game_metadata);
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
            deal_community_cards(game_metadata, 3);
        } else if (game_metadata.stage == STAGE_FLOP) {
            deal_community_cards(game_metadata, 1);
        } else if (game_metadata.stage == STAGE_TURN) {
            deal_community_cards(game_metadata, 1);
        };

        game_metadata.stage = (game_metadata.stage + 1) % 5;
        debug::print(&string::utf8(b"Stage: "));
        debug::print(&game_metadata.stage);
        
        // Skip folded players
        let nextPlayer = vector::borrow(&game_metadata.players, (game_metadata.starter as u64));
        game_metadata.currentPlayerIndex = game_metadata.starter;
        game_metadata.turn = nextPlayer.id;
        //game_metadata.currentPlayerIndex = (((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players) as u8);
        while (nextPlayer.status == STATUS_FOLDED) {
            nextPlayer = vector::borrow(&game_metadata.players, ((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players));
            game_metadata.turn = nextPlayer.id;
            game_metadata.currentPlayerIndex = (((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players) as u8);
        };

        game_metadata.current_bet = 0;

        // Reset current bets
        let i = 0;
        while (i < vector::length(&game_metadata.players)) {
            let player = vector::borrow_mut(&mut game_metadata.players, i);
            player.current_bet = 0;
            player.checked = false;
            i = i + 1;
        };

        game_metadata.lastRaiser = option::none<LastRaiser>();
    }

    /* 
    =================================
      E N T R Y   F U N C T I O N S
    =================================
    */

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

        assert!(amount == game_metadata.stake, ESTAKE_MISMATCH);
        
        aptos_account::transfer(from, @poker, amount);

        debug::print(&string::utf8(b"Now the admin account has: ")); 
        debug::print(&coin::balance<AptosCoin>(@poker));

        vector::push_back(&mut game_metadata.players, Player{id: addr, hand: vector::empty(), status: STATUS_ACTIVE, current_bet: 0, checked: false});
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
        assert_is_owner(signer::address_of(from));

        let gamestate = borrow_global_mut<GameState>(@poker);
        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        assert!(game_metadata.stage == STAGE_SHOWDOWN, EINVALID_STAGE);

        let activePlayers = 0;
        let i = 0;
        let lastActivePlayerIndex = 0;
        while (i < vector::length(&game_metadata.players)) {
            let player = vector::borrow(&game_metadata.players, i);
            if (player.status == STATUS_ACTIVE) {
                activePlayers = activePlayers + 1;
                lastActivePlayerIndex = i;
            };
            i = i + 1;
        };

        debug::print(&string::utf8(b"Active players: "));
        debug::print(&activePlayers);

        if (activePlayers == 1) {
            game_metadata.state = GAMESTATE_CLOSED;
            
            let winner = vector::borrow(&game_metadata.players, lastActivePlayerIndex);
            let players = game_metadata.players;
            
            let winner_index = lastActivePlayerIndex;

            let winner_addr = vector::borrow(&game_metadata.players, winner_index).id;

            let housePot = fixed_point64::multiply_u128((game_metadata.pot as u128), fixed_point64::create_from_rational(1, 100));

            debug::print(&string::utf8(b"HouseRRR Pot: "));
            debug::print(&housePot);

            debug::print(&string::utf8(b"Metadata PotSSSS: "));
            debug::print(&game_metadata.pot);

            let winnerReward = (game_metadata.pot as u128) - housePot;

            debug::print(&string::utf8(b"House Pot: "));
            debug::print(&housePot);

            vector::push_back(&mut game_metadata.winners, winner_addr);

            aptos_account::transfer(from, winner_addr, (winnerReward as u64));

            debug::print(&string::utf8(b"Game metadata: "));
            debug::print(game_metadata);
            create_game(game_metadata.room_id);
            return
        };

        let allCards = vector::empty<Card>();
        vector::append<Card>(&mut allCards, game_metadata.deck);
        vector::append<Card>(&mut allCards, game_metadata.community);
        
        // Append all players' hands
        let i = 0;
        while (i < vector::length(&game_metadata.players)) {
            let player = vector::borrow(&game_metadata.players, i);
            vector::append<Card>(&mut allCards, player.hand);
            i = i + 1;
        };

        debug::print(&string::utf8(b"Length of allCards: "));
        debug::print(&vector::length(&allCards));

        let j: u64 = 0;
        while (j < 52) {
            let (isInDeck, deckIndex) = vector::find<Card>(&game_metadata.deck, |obj| {
                let card: &Card = obj;
                card.cardId == (j as u8)
            });
            let (isInCommunity, communityIndex) = vector::find<Card>(&game_metadata.community, |obj| {
                let card: &Card = obj;
                card.cardId == (j as u8)
            });
            if (isInDeck) {
                debug::print(&string::utf8(b"Found in deck"));
                let card = vector::borrow_mut(&mut game_metadata.deck, deckIndex);
                card.suit_string = *string::bytes(vector::borrow(&suit_strings, j));
                card.value_string = *string::bytes(vector::borrow(&value_strings, j));
            } else if (isInCommunity) {
                debug::print(&string::utf8(b"Found in community"));
                debug::print(&j);
                debug::print(&string::utf8(b"Commuity index: "));
                debug::print(&communityIndex);
                let card = vector::borrow_mut(&mut game_metadata.community, communityIndex);
                card.suit_string = *string::bytes(vector::borrow(&suit_strings, j));
                card.value_string = *string::bytes(vector::borrow(&value_strings, j));
            } else {
                let l = 0;
                while (l < vector::length(&game_metadata.players)) {
                    let player = vector::borrow_mut(&mut game_metadata.players, (l as u64));
                    let (isInHand, handIndex) = vector::find<Card>(&player.hand, |obj| {
                        let card: &Card = obj;
                        card.cardId == (j as u8)
                    });
                    if (isInHand) {
                        let card = vector::borrow_mut<Card>(&mut player.hand, handIndex);
                        card.suit_string = *string::bytes(vector::borrow(&suit_strings, j));
                        card.value_string = *string::bytes(vector::borrow(&value_strings, j));
                    };
                    l = l + 1;
                };
            };
            j = j + 1;
        };

        debug::print(&string::utf8(b"Game metadata: "));
        debug::print(game_metadata);

        // Find winner and end game
        let winners = get_game_winners(game_metadata);
        debug::print(&string::utf8(b"Winners: "));
        debug::print(&winners);

        game_metadata.state = GAMESTATE_CLOSED;
        
        let k = 0;
        while (k < vector::length(&winners)) {
            let winner = vector::borrow(&winners, k);
            let players = game_metadata.players;
            
            let winner_index = winner.player_index;

            let winner_addr = vector::borrow(&game_metadata.players, winner_index).id;

            let housePot = fixed_point64::multiply_u128((game_metadata.pot as u128), fixed_point64::create_from_rational(1, 100));

            debug::print(&string::utf8(b"HouseRRR Pot: "));
            debug::print(&housePot);

            debug::print(&string::utf8(b"Metadata PotSSSS: "));
            debug::print(&game_metadata.pot);

            let winnerReward = (game_metadata.pot as u128) - housePot;
            let winnerRewardDivided = fixed_point64::multiply_u128(winnerReward, fixed_point64::create_from_rational(1, (vector::length(&winners) as u128)));

            debug::print(&string::utf8(b"House Pot: "));
            debug::print(&housePot);

            debug::print(&string::utf8(b"Winner reward divided: "));

            debug::print(&winnerRewardDivided);

            debug::print(&k);

            vector::push_back(&mut game_metadata.winners, winner_addr);

            debug::print(&string::utf8(b"Amount on admin account: "));
            debug::print(&coin::balance<AptosCoin>(@poker));

            aptos_account::transfer(from, winner_addr, (winnerRewardDivided as u64));
            debug::print(&string::utf8(b"Transferred to winner: "));
            debug::print(&winner_addr);
            debug::print(&string::utf8(b"Amount: "));
            debug::print(&winnerRewardDivided);
            k = k + 1;
        };
        debug::print(&string::utf8(b"Game metadata: "));
        debug::print(game_metadata);
        create_game(game_metadata.room_id);
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

        assert!(action >= FOLD && action <= RAISE, EINVALID_MOVE);

        debug::print(&string::utf8(b"Performing action"));
        
        let gamestate = borrow_global_mut<GameState>(@poker);
        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);
        let room_id = game_metadata.room_id;
        let players = (copy game_metadata).players;

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

        debug::print(&string::utf8(b"Current turn: "));
        debug::print(&game_metadata.turn);
        debug::print(&string::utf8(b"Who is attempting: "));
        debug::print(&addr);

        assert!(game_metadata.turn == addr, EINSUFFICIENT_PERMISSIONS);

        // Check if player has enough balance to perform the action
        if (amount > 0) {
            assert!(amount <= coin::balance<AptosCoin>(addr), EINSUFFICIENT_BALANCE);
        };

        if (action == FOLD) {
            player.status = STATUS_FOLDED;
        } else if (action == CHECK) {
            assert!(game_metadata.current_bet == 0, EINVALID_MOVE);
            player.checked = true;
        } else if (action == CALL) {
            debug::print(&string::utf8(b"Call ANNY"));
            let diff = game_metadata.current_bet - player.current_bet;
            debug::print(&string::utf8(b"Current bet: "));
            debug::print(&game_metadata.current_bet);
            debug::print(&string::utf8(b"Player current bet: "));
            debug::print(&player.current_bet);
            debug::print(&string::utf8(b"Diff: "));
            debug::print(&diff);
            player.current_bet = player.current_bet + diff;
            game_metadata.pot = game_metadata.pot + diff;
            aptos_account::transfer(from, @poker, diff);
        } else if (action == RAISE) {
            debug::print(&string::utf8(b"Raise HERE"));
            // Player can only raise to a maximum equal to the lowest balance of the other players
            let max_raise = get_max_raise_for(addr, &players);
            assert!(player.current_bet + amount <= max_raise, ERAISE_TOO_HIGH);
            assert!(player.current_bet + amount >= game_metadata.current_bet, ERAISE_TOO_LOW);

            // Raise has to be at least current bet + stake
            assert!(amount >= game_metadata.stake, ERAISE_TOO_LOW);

            player.current_bet = player.current_bet + amount;

            game_metadata.current_bet = player.current_bet;

            game_metadata.pot = game_metadata.pot + amount;

            aptos_account::transfer(from, @poker, amount);

            game_metadata.lastRaiser = option::some<LastRaiser>(LastRaiser{playerId: addr, playerMove: action});
        };

        if (action != CHECK) {
            player.checked = false;
        };

        game_metadata.last_action_timestamp = timestamp::now_seconds();

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
            game_metadata.stage = STAGE_SHOWDOWN;
            return
        } else if (activePlayers == 0) {
            game_metadata.state = GAMESTATE_CLOSED;
            return
        };

        // Skip folded players
        let nextPlayer = vector::borrow(&game_metadata.players, ((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players));
        game_metadata.turn = nextPlayer.id;
        game_metadata.currentPlayerIndex = (((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players) as u8);
        while (nextPlayer.status == STATUS_FOLDED) {
            nextPlayer = vector::borrow(&game_metadata.players, ((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players));
            game_metadata.turn = nextPlayer.id;
            game_metadata.currentPlayerIndex = (((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players) as u8);
        };

        let should_move_to_next_stage = false;
        
        debug::print(&string::utf8(b"Current player index: "));
        debug::print(&game_metadata.currentPlayerIndex);
        debug::print(&string::utf8(b"Current bet: "));
        debug::print(&game_metadata.current_bet);
        debug::print(&string::utf8(b"Starter: "));
        debug::print(&game_metadata.starter);
        // If it's the starter's turn and all players have called or are all in, move to next stage
        debug::print(&string::utf8(b"All called or checked: "));
        debug::print(&all_have_called_or_checked(&game_metadata.players, game_metadata.current_bet));
        // Starter player might have folded
        let nextPlayerThatIsNotFolded = vector::borrow(&game_metadata.players, (game_metadata.starter as u64));
        let indexNextPlayerThatIsNotFolded = (game_metadata.starter as u64);
        while (nextPlayerThatIsNotFolded.status == STATUS_FOLDED) {
            // player after nextPlayerThatIsNotFolded
            nextPlayerThatIsNotFolded = vector::borrow(&game_metadata.players, ((indexNextPlayerThatIsNotFolded as u64) + 1) % vector::length(&game_metadata.players));
            indexNextPlayerThatIsNotFolded = ((indexNextPlayerThatIsNotFolded as u64) + 1) % vector::length(&game_metadata.players);
        };
        debug::print(&string::utf8(b"Next player that is not folded: "));
        debug::print(nextPlayerThatIsNotFolded);

        let (_, indexNextPlayerThatIsNotFolded) = vector::index_of(&game_metadata.players, nextPlayerThatIsNotFolded);
        if (game_metadata.currentPlayerIndex == (indexNextPlayerThatIsNotFolded as u8) && all_have_called_or_checked(&game_metadata.players, game_metadata.current_bet)) {
            if (all_have_called_or_checked(&game_metadata.players, game_metadata.current_bet)) {
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
            if (lastRaiser.playerId == addrNextPlayer && all_have_called_or_checked(&game_metadata.players, game_metadata.current_bet)) {
                should_move_to_next_stage = true;
            };
        } else {
            debug::print(&string::utf8(b"No last raiser"));
        };

        debug::print(&string::utf8(b"Should move to next stage: "));
        debug::print(&should_move_to_next_stage);
        if (game_metadata.state == GAMESTATE_CLOSED) {
            create_game(room_id);
        };
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
        assert!(time_diff > 30, EINVALID_MOVE);

        let currentPlayer = vector::borrow_mut(&mut game_metadata.players, (game_metadata.currentPlayerIndex as u64));
        currentPlayer.status = STATUS_FOLDED;

        let activePlayers = 0;
        let i = 0;
        let lastActivePlayerIndex = 0;
        while (i < vector::length(&game_metadata.players)) {
            let player = vector::borrow(&game_metadata.players, i);
            if (player.status == STATUS_ACTIVE) {
                activePlayers = activePlayers + 1;
                lastActivePlayerIndex = i;
            };
            i = i + 1;
        };

        if (activePlayers == 1) {
            game_metadata.stage = STAGE_SHOWDOWN;
            return
        } else if (activePlayers == 0) {
            game_metadata.state = GAMESTATE_CLOSED;
            return
        };
        
        let nextPlayer = vector::borrow(&game_metadata.players, ((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players));
        game_metadata.turn = nextPlayer.id;
        game_metadata.currentPlayerIndex = (((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players) as u8);
        // Skip folded players
        while (nextPlayer.status == STATUS_FOLDED) {
            nextPlayer = vector::borrow(&game_metadata.players, ((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players));
            game_metadata.turn = nextPlayer.id;
            game_metadata.currentPlayerIndex = (((game_metadata.currentPlayerIndex as u64) + 1) % vector::length(&game_metadata.players) as u8);
        };
        game_metadata.last_action_timestamp = timestamp::now_seconds();
    }

    fun initialize_deck(game: &mut GameMetadata) {
        
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

    fun deal_hole_cards(game_metadata: &mut GameMetadata) {
        let i = 0;
        let players_len = vector::length(&game_metadata.players);
        while (i < players_len) {
            let player = vector::borrow_mut(&mut game_metadata.players, i);
            vector::push_back(&mut player.hand, vector::pop_back(&mut game_metadata.deck));
            vector::push_back(&mut player.hand, vector::pop_back(&mut game_metadata.deck));
            i = i + 1;
        };
    }


    fun deal_community_cards(game_metadata: &mut GameMetadata, number: u8) {
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

    fun evaluate_hand_details(cards: &vector<Card>): (vector<u8>, u8, u8, simple_map::SimpleMap<u8, vector<u8>>) {
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
        let bestCombinationHighestValue = simple_map::new<u8, vector<u8>>();
        let n = 1;
        while (n < 10) {
            simple_map::upsert(&mut bestCombinationHighestValue, (n as u8), vector::empty());
            n = n + 1;
        };
        
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

        if (_flush) {
            let array = simple_map::borrow_mut(&mut bestCombinationHighestValue, &6);
            vector::push_back(array, highestValue);
        };
        
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
                        let array = simple_map::borrow_mut(&mut bestCombinationHighestValue, &5);
                        if (vector::length(array) > 0) {
                            vector::pop_back(array);
                        };
                        vector::push_back(array, idx);
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
                let array = simple_map::borrow_mut(&mut bestCombinationHighestValue, &5);
                if (vector::length(array) > 0) {
                    vector::pop_back(array);
                };
                vector::push_back(array, 12);
                break
            };
        };

        // I'll have to get the keys and values of the map and iterate over them
        let keys = simple_map::keys<u8, u8>(&values);
        let len = vector::length(&keys);
        let j = 0;
        while (j < len) {
            let key = vector::borrow(&keys, j);
            let value = simple_map::borrow<u8, u8>(&values, key);
            if (*value == 2) {

                if (pairs == 1) {
                    let tempHandRank = 3;
                    let array2 = *simple_map::borrow(&bestCombinationHighestValue, &2);
                    let array = simple_map::borrow_mut(&mut bestCombinationHighestValue, &tempHandRank);
                    let key_value = *key;
                    {
                        let lastItem = vector::borrow(&array2, 0);
                        vector::push_back(array, *lastItem);
                    };

                    // Now you can use the copied value
                    vector::push_back(array, key_value);
                } else {
                    let array = simple_map::borrow_mut(&mut bestCombinationHighestValue, &2);
                    vector::push_back(array, *key);
                };

                pairs = pairs + 1;

            } else if (*value == 3) {
                let array = simple_map::borrow_mut(&mut bestCombinationHighestValue, &4);
                vector::push_back(array, *key);
                threeOfAKind = threeOfAKind + 1;
            } else if (*value == 4) {
                let array = simple_map::borrow_mut(&mut bestCombinationHighestValue, &8);
                vector::push_back(array, *key);
                fourOfAKind = fourOfAKind + 1;
            };
            j = j + 1;
        };
        
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
        
       /*  debug::print(&string::utf8(b"Best comparison highest value: "));
        let array2 = *simple_map::borrow(&bestCombinationHighestValue, &2);
        let array3 = *simple_map::borrow(&bestCombinationHighestValue, &3);
        let array2value = vector::borrow(&array2, 0);
        let array3value = vector::borrow(&array3, 1);
        debug::print(array2value);
        debug::print(array3value);
        debug::print(&string::utf8(b"Hand type: "));
        debug::print(&string::utf8(handType));
 */
        (handType, handRank, highestValue, bestCombinationHighestValue)
    }

    /*
        struct Evaluation has drop, copy {
        player_index: u64,
        hand_rank: u8,
        comparison_value: u8,
        hand_type: vector<u8>,
        bestCombinationHighestValue: simple_map::SimpleMap<u8, vector<u8>>,
    }
    */

    fun evaluate_winner_with_same_hand_rank(evaluation1: Evaluation, evaluation2: Evaluation): option::Option<Evaluation> {
        let handRank = evaluation1.hand_rank;
        let comparisonValue1 = evaluation1.comparison_value;
        let comparisonValue2 = evaluation2.comparison_value;
        let bestCombinationHighestValue1 = evaluation1.bestCombinationHighestValue;
        let bestCombinationHighestValue2 = evaluation2.bestCombinationHighestValue;

        if (handRank == 1) {
            if (comparisonValue1 > comparisonValue2) {
                return option::some(evaluation1)
            } else if (comparisonValue1 < comparisonValue2) {
                return option::some(evaluation2)
            };
            return option::none<Evaluation>()
        };

        if (handRank == 7) {
            {
                let fullhousePair = simple_map::borrow(&bestCombinationHighestValue1, &2);
                let fullhouseTrio = simple_map::borrow(&bestCombinationHighestValue1, &4);
                let fullhousePairItem = vector::borrow(fullhousePair, 0);
                let fullhouseTrioItem = vector::borrow(fullhouseTrio, 0);
                let fullhouseArray = vector[(*fullhousePairItem), (*fullhouseTrioItem)];
                simple_map::upsert(&mut bestCombinationHighestValue1, 7, fullhouseArray);
            };
            {
                let fullhousePair = simple_map::borrow(&bestCombinationHighestValue2, &2);
                let fullhouseTrio = simple_map::borrow(&bestCombinationHighestValue2, &4);
                let fullhousePairItem = vector::borrow(fullhousePair, 0);
                let fullhouseTrioItem = vector::borrow(fullhouseTrio, 0);
                let fullhouseArray = vector[(*fullhousePairItem), (*fullhouseTrioItem)];
                simple_map::upsert(&mut bestCombinationHighestValue2, 7, fullhouseArray);
            };
        } else if (handRank == 9) {
            {
                let straightFlushStraight = simple_map::borrow(&bestCombinationHighestValue1, &5);
                let straightFlushFlush = simple_map::borrow(&bestCombinationHighestValue1, &6);
                let straightFlushStraightItem = vector::borrow(straightFlushStraight, 0);
                let straightFlushFlushItem = vector::borrow(straightFlushFlush, 0);
                let straightFlushArray = vector[(*straightFlushStraightItem), (*straightFlushFlushItem)];
                simple_map::upsert(&mut bestCombinationHighestValue1, 9, straightFlushArray);
            };
            {
                let straightFlushPair = simple_map::borrow(&bestCombinationHighestValue2, &5);
                let straightFlushFlush = simple_map::borrow(&bestCombinationHighestValue2, &6);
                let straightFlushPairItem = vector::borrow(straightFlushPair, 0);
                let straightFlushFlushItem = vector::borrow(straightFlushFlush, 0);
                let straightFlushArray = vector[(*straightFlushPairItem), (*straightFlushFlushItem)];
                simple_map::upsert(&mut bestCombinationHighestValue2, 9, straightFlushArray);
            };
        };

        let bestCombinationHighestValue1Array = simple_map::borrow(&bestCombinationHighestValue1, &handRank);
        let bestCombinationHighestValue2Array = simple_map::borrow(&bestCombinationHighestValue2, &handRank);
        let bestCombinationHighestValue1_len = vector::length(bestCombinationHighestValue1Array);
        let bestCombinationHighestValue2_len = vector::length(bestCombinationHighestValue2Array);
        let bestCombinationHighestValue1_last = vector::borrow(bestCombinationHighestValue1Array, (bestCombinationHighestValue1_len - 1));
        let bestCombinationHighestValue2_last = vector::borrow(bestCombinationHighestValue2Array, (bestCombinationHighestValue2_len - 1));

        if ((*bestCombinationHighestValue1_last) > (*bestCombinationHighestValue2_last)) {
            return option::some(evaluation1)
        } else if ((*bestCombinationHighestValue1_last) < (*bestCombinationHighestValue2_last)) {
            return option::some(evaluation2)
        } else if (bestCombinationHighestValue1_len > bestCombinationHighestValue2_len) {
            let bestCombinationHighestValue1_second_last = vector::borrow(bestCombinationHighestValue1Array, (bestCombinationHighestValue1_len - 2));
            let bestCombinationHighestValue2_second_last = vector::borrow(bestCombinationHighestValue2Array, (bestCombinationHighestValue2_len - 2));
            if ((*bestCombinationHighestValue1_second_last) > (*bestCombinationHighestValue2_second_last)) {
                return option::some(evaluation1)
            } else if ((*bestCombinationHighestValue1_second_last) < (*bestCombinationHighestValue2_second_last)) {
                return option::some(evaluation2)
            };
        };

        if (comparisonValue1 > comparisonValue2) {
            return option::some(evaluation1)
        } else if (comparisonValue1 < comparisonValue2) {
            return option::some(evaluation2)
        };
        return option::none<Evaluation>()
    }

    fun evaluate_hand(communityCards: &vector<Card>, playerCards: &vector<Card>): (vector<u8>, u8, u8, simple_map::SimpleMap<u8, vector<u8>>) {
        let newCards = vector::empty<Card>();
        vector::append<Card>(&mut newCards, *communityCards);
        vector::append<Card>(&mut newCards, *playerCards);
        evaluate_hand_details(&newCards)
    }

    fun get_game_winners(game_metadata: &mut GameMetadata): vector<Evaluation> {
        let players_len = vector::length(&game_metadata.players);
        let evaluations: vector<Evaluation> = vector::empty();

        let i = 0;
        while (i < players_len) {
            let player = vector::borrow(&game_metadata.players, i);
            if (player.status == STATUS_ACTIVE) {
                let (hand_type, hand_rank, highest_value, bestCombinationHighestValue) = evaluate_hand(&game_metadata.community, &player.hand);
                
                let evaluation = Evaluation {
                    player_index: i,
                    hand_rank: hand_rank,
                    comparison_value: highest_value,
                    hand_type: hand_type,
                    bestCombinationHighestValue: bestCombinationHighestValue,
                };
                vector::push_back(&mut evaluations, evaluation);
            };
            i = i + 1;
        };

        assert!(vector::length(&evaluations) > 0, EINVALID_GAME);

        // Initialize tracking for potential winners
        let winners: vector<Evaluation> = vector::empty();
        let eval_index = 1;

        while (eval_index < vector::length(&evaluations)) {
            if (vector::is_empty(&winners)) {
                vector::push_back(&mut winners, *vector::borrow(&evaluations, 0));
            };
            let j = 0;
            let curr_evaluation = vector::borrow(&evaluations, eval_index);
            while (j < vector::length(&winners)) {
                let prevWinner = vector::borrow(&winners, j);
                if (prevWinner.hand_rank == curr_evaluation.hand_rank) {
                    if (prevWinner.player_index == curr_evaluation.player_index) {
                        break
                    };

                    let winnerEvaluation = evaluate_winner_with_same_hand_rank(*prevWinner, *curr_evaluation);
                    if (option::is_some(&winnerEvaluation)) {
                        winners = vector::empty();
                        vector::push_back(&mut winners, *option::borrow(&winnerEvaluation));
                    } else if (option::is_none(&winnerEvaluation)) {
                        vector::push_back(&mut winners, *curr_evaluation);
                    };
                } else if (prevWinner.hand_rank < curr_evaluation.hand_rank) {
                    winners = vector::empty();
                    vector::push_back(&mut winners, *curr_evaluation);
                };
            j = j + 1;
            };
            eval_index = eval_index + 1;
        };
        winners
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
        aptos_coin::mint(aptos_framework, signer::address_of(account2), 90000000);
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
        join_game(account2, 1, 5000000);
        join_game(account3, 1, 5000000);
        join_game(account4, 1, 5000000);

        debug::print(&string::utf8(b"Amount on admin account START: "));
        debug::print(&coin::balance<AptosCoin>(@poker));

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

        debug::print(&string::utf8(b"Game stage: "));
        debug::print(&game_metadata.stage);

        // Actions
        {
            perform_action(account3, game_id, RAISE, 8000000);
            perform_action(account4, game_id, CALL, 8000000);
            perform_action(account1, game_id, CALL, 8000000);
            perform_action(account2, game_id, RAISE, 20000000);
            perform_action(account3, game_id, FOLD, 0);
            perform_action(account4, game_id, CALL, 0);
            perform_action(account1, game_id, FOLD, 0);
            
            let game_metadata = get_game_metadata_by_id(game_id);

            debug::print(&string::utf8(b"Game METADATA 2: "));
            debug::print(&game_metadata);

            assert!(game_metadata.stage == STAGE_FLOP, EINVALID_GAME);
        };

        /* {
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
                    player.hand = vector[Card{cardId: 4, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 5, suit_string: b"clubs", value_string: b"10"}];
                } else if (i == 3) {
                    player.hand = vector[Card{cardId: 6, suit_string: b"spades", value_string: b"3"}, Card{cardId: 7, suit_string: b"spades", value_string: b"jack"}];
                };
                // Add more conditions as necessary for other players

                i = i + 1;
            };
            
        }; */

        {
            //perform_action(account3, game_id, FOLD, 8000000);
            perform_action(account4, game_id, RAISE, 13000000);
            //perform_action(account1, game_id, FOLD, 13000000);
            perform_action(account2, game_id, RAISE, 18000000);
            //perform_action(account3, game_id, CALL, 18000000);
            perform_action(account4, game_id, RAISE, 20000000);
            perform_action(account2, game_id, CALL, 20000000);
            
            //perform_action(account1, game_id, CALL, 18000000);

            let game_metadata = get_game_metadata_by_id(game_id);

            assert!(game_metadata.stage == STAGE_TURN, EINVALID_GAME);
            assert!(vector::length(&game_metadata.community) == 4, EINVALID_GAME);
        };

        {
            //perform_action(account3, game_id, CHECK, 0);
            perform_action(account4, game_id, CHECK, 0);
            /* perform_action(account1, game_id, CHECK, 0); */
            perform_action(account2, game_id, RAISE, 10000000);
            //perform_action(account3, game_id, CALL, 10000000);
            perform_action(account4, game_id, CALL, 10000000);
            /* perform_action(account1, game_id, CALL, 10000000); */

            let game_metadata = get_game_metadata_by_id(game_id);

            assert!(game_metadata.stage == STAGE_RIVER, EINVALID_GAME);
            assert!(vector::length(&game_metadata.community) == 5, EINVALID_GAME);
        };

        {
            //perform_action(account3, game_id, RAISE, 5000000);
            perform_action(account4, game_id, RAISE, 10000000);
            /* perform_action(account1, game_id, CALL, 10000000); */
            perform_action(account2, game_id, CALL, 10000000);
            //perform_action(account3, game_id, CALL, 10000000);

            let game_metadata = get_game_metadata_by_id(game_id);

            assert!(game_metadata.stage == STAGE_SHOWDOWN, EINVALID_GAME);
            assert!(vector::length(&game_metadata.community) == 5, EINVALID_GAME);
        };

        game_metadata.seed = 35;

            populate_card_values(admin, game_id,
        vector[
            string::utf8(b"diamonds"), string::utf8(b"diamonds"), string::utf8(b"diamonds"), string::utf8(b"clubs"),
            string::utf8(b"diamonds"), string::utf8(b"clubs"),    string::utf8(b"clubs"),    string::utf8(b"hearts"),
            string::utf8(b"spades"),   string::utf8(b"clubs"),    string::utf8(b"hearts"),   string::utf8(b"hearts"),
            string::utf8(b"spades"),   string::utf8(b"spades"),   string::utf8(b"diamonds"), string::utf8(b"spades"),
            string::utf8(b"clubs"),    string::utf8(b"spades"),   string::utf8(b"hearts"),   string::utf8(b"hearts"),
            string::utf8(b"hearts"),   string::utf8(b"hearts"),   string::utf8(b"hearts"),   string::utf8(b"diamonds"),
            string::utf8(b"spades"),   string::utf8(b"spades"),   string::utf8(b"clubs"),    string::utf8(b"clubs"),
            string::utf8(b"spades"),   string::utf8(b"spades"),   string::utf8(b"clubs"),    string::utf8(b"clubs"),
            string::utf8(b"diamonds"), string::utf8(b"spades"),   string::utf8(b"clubs"),    string::utf8(b"diamonds"),
            string::utf8(b"hearts"),   string::utf8(b"hearts"),   string::utf8(b"diamonds"), string::utf8(b"spades"),
            string::utf8(b"spades"),   string::utf8(b"clubs"),    string::utf8(b"clubs"),    string::utf8(b"spades"),
            string::utf8(b"diamonds"), string::utf8(b"diamonds"), string::utf8(b"diamonds"), string::utf8(b"hearts"),
            string::utf8(b"diamonds"), string::utf8(b"clubs"),    string::utf8(b"hearts"),   string::utf8(b"hearts"),
        ],
        vector[
            string::utf8(b"8"),      string::utf8(b"6"),      string::utf8(b"ace"),    string::utf8(b"jack"), string::utf8(b"2"),    
            string::utf8(b"ace"),    string::utf8(b"4"),      string::utf8(b"jack"),   string::utf8(b"queen"),string::utf8(b"6"),    
            string::utf8(b"8"),      string::utf8(b"7"),      string::utf8(b"2"),      string::utf8(b"3"),    string::utf8(b"queen"),
            string::utf8(b"king"),   string::utf8(b"king"),   string::utf8(b"6"),      string::utf8(b"ace"),  string::utf8(b"king"), 
            string::utf8(b"10"),     string::utf8(b"9"),      string::utf8(b"3"),      string::utf8(b"jack"), string::utf8(b"10"),   
            string::utf8(b"jack"),   string::utf8(b"3"),      string::utf8(b"9"),      string::utf8(b"7"),    string::utf8(b"8"),    
            string::utf8(b"7"),      string::utf8(b"2"),      string::utf8(b"9"),      string::utf8(b"ace"),  string::utf8(b"queen"),
            string::utf8(b"3"),      string::utf8(b"5"),      string::utf8(b"queen"),  string::utf8(b"10"),   string::utf8(b"5"),    
            string::utf8(b"9"),      string::utf8(b"5"),      string::utf8(b"10"),     string::utf8(b"4"),    string::utf8(b"king"),  
            string::utf8(b"7"),      string::utf8(b"5"),      string::utf8(b"6"),      string::utf8(b"4"),    string::utf8(b"8"),    
            string::utf8(b"2"),      string::utf8(b"4")
        ]

        );
        
        {
            let game_metadata = get_game_metadata_by_id(game_id);
            debug::print(&string::utf8(b"Game metadata X: "));
            debug::print(&game_metadata);
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
            checked: false,
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
            Card{cardId: 2, suit_string: b"clubs", value_string: b"7"},
            ]
        );
        
        let player1 = create_player(@0x1, vector[Card{cardId: 3, suit_string: b"hearts", value_string: b"3"}, Card{cardId: 7, suit_string: b"diamonds", value_string: b"4"}]);
        let player2 = create_player(@0x2, vector[Card{cardId: 4, suit_string: b"clubs", value_string: b"5"}, Card{cardId: 8, suit_string: b"spades", value_string: b"6"}]);
        let player3 = create_player(@0x3, vector[Card{cardId: 5, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 9, suit_string: b"diamonds", value_string: b"9"}]);
        let player4 = create_player(@0x4, vector[Card{cardId: 6, suit_string: b"spades", value_string: b"3"}, Card{cardId: 10, suit_string: b"spades", value_string: b"jack"}]);

        game_metadata.players = vector[player1, player2, player3, player4];
        
        /* let winners = get_game_winners(&mut game_metadata);
        debug::print(&string::utf8(b"Winners -----> "));
        debug::print(&winners);
        let winner = vector::borrow(&winners, 0);

        assert!(winner.player_index == 3, EINVALID_GAME); */

        // One pair

        game_metadata.community = vector::empty();
        vector::append(&mut game_metadata.community, 
            vector[
            Card{cardId: 0, suit_string: b"spades", value_string: b"6"},
            Card{cardId: 1, suit_string: b"diamonds", value_string: b"2"},
            Card{cardId: 2, suit_string: b"diamonds", value_string: b"7"},
            Card{cardId: 2, suit_string: b"diamonds", value_string: b"8"},
            Card{cardId: 2, suit_string: b"spades", value_string: b"10"},
            ]
        );

        player1.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"7"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"queen"}];
        player2.hand = vector[Card{cardId: 2, suit_string: b"diamonds", value_string: b"jack"}, Card{cardId: 3, suit_string: b"clubs", value_string: b"10"}];

        game_metadata.players = vector[player1, player2];

        /* winner = vector::borrow(&get_game_winners(&mut game_metadata), 0);

        debug::print(winner);

        assert!(winner.player_index == 1, EINVALID_GAME); */

        // Two pair

        game_metadata.community = vector::empty();

        vector::append(&mut game_metadata.community, 
            vector[
            Card{cardId: 0, suit_string: b"spades", value_string: b"2"},
            Card{cardId: 1, suit_string: b"diamonds", value_string: b"10"},
            Card{cardId: 2, suit_string: b"clubs", value_string: b"7"},
            ]
        );

        debug::print(&string::utf8(b"Two pair: "));
        player1.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"3"}, Card{cardId: 1, suit_string: b"diamonds", value_string: b"4"}];
        player2.hand = vector[Card{cardId: 2, suit_string: b"clubs", value_string: b"7"}, Card{cardId: 3, suit_string: b"spades", value_string: b"2"}];
        player3.hand = vector[Card{cardId: 0, suit_string: b"hearts", value_string: b"8"}, Card{cardId: 1, suit_string: b"clubs", value_string: b"10"}];
        player4.hand = vector[Card{cardId: 2, suit_string: b"spades", value_string: b"3"}, Card{cardId: 3, suit_string: b"spades", value_string: b"jack"}];

        game_metadata.players = vector[player1, player2, player3];

        /* let (hand_type, hand_rank, highest_value, bestCombinationHighestValue) = evaluate_hand(&game_metadata.community, &player2.hand);

        assert!(hand_type == b"Two Pair", EINVALID_GAME); */

        let winner = vector::borrow(&get_game_winners(&mut game_metadata), 0);

        debug::print(&string::utf8(b"Winner: "));
        debug::print(winner);

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
        
        winner = vector::borrow(&get_game_winners(&mut game_metadata), 0);

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

        winner = vector::borrow(&get_game_winners(&mut game_metadata), 0);

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


        winner = vector::borrow(&get_game_winners(&mut game_metadata), 0);

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


        winner = vector::borrow(&get_game_winners(&mut game_metadata), 0);

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

        winner = vector::borrow(&get_game_winners(&mut game_metadata), 0);

        debug::print(&string::utf8(b"Winner: "));
        debug::print(winner);

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

        winner = vector::borrow(&get_game_winners(&mut game_metadata), 0);

        assert!(winner.player_index == 3, EINVALID_GAME);
    }
}