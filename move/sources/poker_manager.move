module poker::poker_manager {
    use 0x1::signer;
    use 0x1::vector;
    use 0x1::coin;
    use 0x1::aptos_coin::AptosCoin; 
    use 0x1::aptos_account;
    use 0x1::aptos_coin;
    use std::account;
    use std::string;
    use std::option;
    use std::randomness;
    use std::simple_map::{SimpleMap,Self};
    use std::debug;

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
    const EINVALID_CARD: u64 = 12;

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
    const BET: u64 = 5;

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
        suit: u8,
        value: u8,
        suit_string: vector<u8>,
        value_string: vector<u8>,
    }

    struct Player has drop, copy, store {
        id: address,
        hand: vector<Card>,
        status: u8
    }

    struct LastRaiser has drop, copy, store {
        playerIndex: address,
        playerMove: u32,
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
        playerMove: u32,
        lastRaiser: option::Option<LastRaiser>,
        gameEnded: bool,
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
            LOW_STAKES;
        } else if (room_id <= 8) {
            MEDIUM_STAKES;
        };
        HIGH_STAKES
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
            playerMove: 0,
            lastRaiser: option::none<LastRaiser>(),
            gameEnded: false,
            seed: 0,
            starter: random_player,
            last_action_timestamp: 0,
            current_bet: 0,
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

        let game_metadata = create_game_metadata(1, 1);

        simple_map::add(&mut gamestate.games, game_metadata.id, game_metadata);

        move_to(acc, gamestate);
    }

    // View functions
    #[view]
    public fun get_game_by_id(game_id: u64): GameMetadata {
        assert_is_initialized();
        get_game_metadata_by_id(game_id)
    }

    // Action functions

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

    public entry fun create_game(acc: &signer, room_id: u64) acquires GameState {
        let addr = signer::address_of(acc);
        assert_is_initialized();
        assert_is_owner(addr);

        let gamestate = borrow_global_mut<GameState>(@poker);

        // Add a new game to the global state
        let game_metadata = create_game_metadata(vector::length<u64>(&simple_map::keys(&gamestate.games)) + 1, room_id);

        simple_map::add(&mut gamestate.games, game_metadata.id, game_metadata);
    }

    // When user joins and places a bet
    public entry fun join_game(from: &signer, game_id: u64, amount: u64) acquires GameState, UserGames {
        let from_acc_balance:u64 = coin::balance<AptosCoin>(signer::address_of(from));
        let addr = signer::address_of(from);

        assert!(amount <= from_acc_balance, EINSUFFICIENT_BALANCE);
        
        assert_account_is_not_in_open_game(addr);

        let gamestate = borrow_global_mut<GameState>(@poker);

        assert!(simple_map::contains_key(&gamestate.games, &game_id), EINVALID_GAME);

        let game_metadata = simple_map::borrow_mut(&mut gamestate.games, &game_id);

        assert!(vector::length(&game_metadata.players) < 4, ETABLE_IS_FULL);

        assert!(game_metadata.state == GAMESTATE_OPEN, EGAME_ALREADY_STARTED);

        assert!(amount >= game_metadata.stake, EINSUFFICIENT_BALANCE_FOR_STAKE);
        
        aptos_account::transfer(from, @poker, amount); 

        vector::push_back(&mut game_metadata.players, Player{id: addr, hand: vector::empty()});
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

        let (is_player_in_game, player_index) = find_player_by_address(&game_metadata.players, &addr);
        assert!(is_player_in_game, ENOT_IN_GAME);

        vector::remove(&mut game_metadata.players, player_index);

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

        assert!(game_metadata.turn == addr, EINSUFFICIENT_PERMISSIONS);

        if (action == FOLD) {
            player.status = STATUS_FOLDED;
        } else if (action == CHECK) {
            // Do nothing
        } else if (action == CALL) {
            let diff = game_metadata.current_bet - player.current_bet;
            assert!(diff <= amount, EINVALID_MOVE);
            player.current_bet = player.current_bet + diff;
            game_metadata.pot = game_metadata.pot + diff;
        } else if (action == RAISE) {
            assert!(amount > game_metadata.current_bet, EINVALID_MOVE);
            player.current_bet = player.current_bet + amount;
            game_metadata.pot = game_metadata.pot + amount;
            game_metadata.current_bet = amount;
        } else if (action == ALL_IN) {
            player.current_bet = player.current_bet + amount;
            game_metadata.pot = game_metadata.pot + amount;
            game_metadata.current_bet = amount;
            player.status = STATUS_ALL_IN;
        } else if (action == BET) {
            assert!(amount >= game_metadata.current_bet, EINVALID_MOVE);
            player.current_bet = player.current_bet + amount;
            game_metadata.pot = game_metadata.pot + amount;
            game_metadata.current_bet = amount;
        }

        game_metadata.last_action_timestamp = chain::timestamp();
        game_metadata.turn = player_index + 1;
    }

    fun initializeDeck(game: &mut GameMetadata) {
        let suits: vector<u8> = vector[0, 1, 2, 3]; // 0 = hearts, 1 = diamonds, 2 = clubs, 3 = spades
        let values: vector<u8> = vector[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];

        let i = 0;
        while (i < vector::length(&suits)) {
            let suit = vector::borrow(&suits, i);
            let j = 0;
            while (j < vector::length(&values)) {
                let value = vector::borrow(&values, j);
                vector::push_back(&mut game.deck, Card {
                    suit: *suit,
                    value: *value,
                    suit_string: b"",
                    value_string: b""
                });
                j = j + 1;
            };
            i = i + 1;
        };

        game.seed = randomness::u8_range(0, 51);
    }
    
    fun initializePlayers(game_metadata: &mut GameMetadata, players: &vector<address>) {
        let i = 0;
        let players_len = vector::length(players);
        while (i < players_len) {
            let player = vector::borrow(players, i);
            vector::push_back(&mut game_metadata.players, Player{id: *player, hand: vector::empty()});
            i = i + 1;
        };
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


        // Print suits and values map
        debug::print(&suits);
        debug::print(&values);

        _flush = vector::any<u8>(&simple_map::values<vector<u8>, u8>(&suits), |count| {
            *count >= 5 
        });

        let _consecutive: u8 = 0;
        for (idx in 0..13) {
            let hasConsecutive = simple_map::contains_key<u8, u8>(&values, &idx);
            if (!hasConsecutive) {
                _consecutive = 0;
            } else {
                _consecutive = *simple_map::borrow<u8, u8>(&values, &idx) + 1;
            };
            if (_consecutive >= 5) {
               straight = true;
            }
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
        vector::append<Card>(&mut newCards, communityCards);
        vector::append<Card>(&mut newCards, playerCards);
        evaluateHandDetails(&newCards)
    }

    fun get_game_winner(game_metadata: &mut GameMetadata): address {
        let evaluations = vector::map(&vector::filter(&game_metadata.players, |player| {
            player.status == STATUS_ACTIVE
        }), |player| {
            let evaluation = evaluateHand(&game_metadata.community, &player.hand);
            (player.id, evaluation)
        });

        let (winner, _) = vector::reduce(&evaluations, |prev, current| {
            if (prev.evaluation.handRank == current.evaluation.handRank) {
                return if (prev.evaluation.comparisonValue > current.evaluation.comparisonValue) {
                    prev
                } else {
                    current
                };
            };
            return if (prev.evaluation.handRank > current.evaluation.handRank) {
                prev
            } else {
                current
            };
        });

        game_metadata.winner = winner.id;

    }

    // Unit Tests

    // Tests all poker hands (from high card to straight flush)
    #[test(admin = @poker, aptos_framework = @0x1)]
    fun test_poker_hands() {
        // Evaluate all hands only take into consideration the value_string and suit_string of the cards, 
        // disregarding the suit and value fields

        // Test for High Card, 4 hands
        let game_metadata = create_game_metadata(1, 1);

        // Example: {suit: 0, value: 0, suit_string: b"hearts", value_string: b"2"}
        let hands = vector[
            vector[Card{suit: 0, value: 0, suit_string: b"hearts", value_string: b"2"}, Card{suit: 1, value: 0, suit_string: b"diamonds", value_string: b"3"}, Card{suit: 2, value: 0, suit_string: b"clubs", value_string: b"4"}, Card{suit: 3, value: 0, suit_string: b"spades", value_string: b"5"}, Card{suit: 0, value: 0, suit_string: b"hearts", value_string: b"6"}],
            vector[Card{suit: 0, value: 0, suit_string: b"hearts", value_string: b"2"}, Card{suit: 1, value: 0, suit_string: b"diamonds", value_string: b"3"}, Card{suit: 2, value: 0, suit_string: b"clubs", value_string: b"4"}, Card{suit: 3, value: 0, suit_string: b"spades", value_string: b"5"}, Card{suit: 0, value: 0, suit_string: b"hearts", value_string: b"7"}],
            vector[Card{suit: 0, value: 0, suit_string: b"hearts", value_string: b"2"}, Card{suit: 1, value: 0, suit_string: b"diamonds", value_string: b"3"}, Card{suit: 2, value: 0, suit_string: b"clubs", value_string: b"4"}, Card{suit: 3, value: 0, suit_string: b"spades", value_string: b"5"}, Card{suit: 0, value: 0, suit_string: b"hearts", value_string: b"8"}],
            vector[Card{suit: 0, value: 0, suit_string: b"hearts", value_string: b"2"}, Card{suit: 1, value: 0, suit_string: b"diamonds", value_string: b"3"}, Card{suit: 2, value: 0, suit_string: b"clubs", value_string: b"4"}, Card{suit: 3, value: 0, suit_string: b"spades", value_string: b"5"}, Card{suit: 0, value: 0, suit_string: b"hearts", value_string: b"9"}]
        ];

        let winner = get_game_winner(&mut game_metadata);

        debug::print(&winner);
    }
}