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

    // Card hierarchy
    const CARD_HIERARCHY: vector<u8> = vector[b"2", b"3", b"4", b"5", b"6", b"7", b"8", b"9", b"10", b"jack", b"queen", b"king", b"ace"];

    // Structs
    struct Card has drop, copy {
        suit: u8,
        value: u8,
        suit_string: vector<u8>,
        value_string: vector<u8>,

    }

    struct Player has drop, copy, store {
        id: address,
        hand: vector<Card>,

    }

    struct LastRaiser has drop, copy {
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
        lastRaiser: Option<LastRaiser>,
        gameEnded: bool,
        seed: u64,
        id: u64,
        room_id: u64,
        stake: u64,
        pot: u64,
        starter: u64,
        state: u64,
        last_action_timestamp: u64,
        turn: address,
        current_bet: u64,
        continueBetting: bool,
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
            turn: @0x0,
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
            turn: @0x0,
            winner: @0x0,
            players: vector::empty(),
        };

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

    fun initializeDeck(game: &mut GameMetadata) {
        let suits = vector[0, 1, 2, 3]; // 0 = hearts, 1 = diamonds, 2 = clubs, 3 = spades
        let values = vector[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
        
        let i = 0;
        while (i < vector::length(&suits)) {
            let suit = vector::borrow(&suits, i);
            let j = 0;
            while (j < vector::length(&values)) {
                let value = vector::borrow(&values, j);
                vector::push_back(&mut game.deck, Card {
                    suit: suit,
                    value: value,
                    suit_string: b"",
                    value_string: b""
                });
                j = j + 1;
            };
            i = i + 1;
        };

        GameMetadata.seed = randomness::u8_range(0, 51);
    }
    
    fun initializePlayers(game_metadata: &GameMetadata, players: &vector<address>) {
        let i = 0;
        while (i < vector::length(players)) {
            let player = vector::borrow(players, i);
            vector::push_back(&mut game_metadata.players, Player{id: *player, hand: vector::new()});
            i = i + 1;
        };
    }

    fun dealHoleCards(game_metadata: &GameMetadata) {
        let i = 0;
        while (i < vector::length(&game_metadata.players)) {
                let player = vector::borrow_mut(&game_metadata.players, i);
                vector::push_back(&mut player.hand, vector::pop_back(&mut game_metadata.deck));
                vector::push_back(&mut player.hand, vector::pop_back(&mut game_metadata.deck));
                i = i + 1;
        };
    }

    fun dealCommunityCards(game_metadata: &mut GameMetadata, number: u8) {
        let deck_size = vector::length(&game_metadata.deck);
        if (number > deck_size) {
            debug::print(b"Not enough cards in the deck to deal the requested number of community cards.");
        };

        let i: u64 = 0;
        while (i < number) {
            let index = (i + game_metadata.seed) % deck_size;
            let card = vector::remove(&mut game_metadata.deck, index);
            vector::push_back(&mut game_metadata.community, card);
            i = i + 1;
        }
    }

    fun evaluateHandDetails(cards: &vector<Card>): (string::String, u8, u8) {
        let hand = Card{suit: 0, value: 0, suit_string: b"", value_string: b""};
        let straight: bool = false;
        let flush: bool = false;
        let handType: string::String = string::utf8(b"High Card");
        let handRank: u8 = 1;
        let highestValue: u8 = 0;
        let pairs: u8 = 0;
        let threeOfAKind: u8 = 0;
        let fourOfAKind: u8 = 0;
        let suits: SimpleMap<string::String, u8> = simple_map::new();
        let values = SimpleMap<u8, u8> = simple_map::new();
        let highestValue: u8 = 0;
        let i = 0;
        while (i < vector::length(&cards)) {
            let card = vector::borrow(&cards, i);
            let suit = card.suit_string;
            let value = card.value_string;
            let suitCount = simple_map::borrow(&suits, suit);
            
            if (option::is_none(suitCount)) {
                simple_map::upsert(&mut suits, suit, 1);
            } else {
                let unwrapped_count = option::borrow(suitCount); // Ensure it's 'some'
                 simple_map::upsert(&mut suits, suit, *unwrapped_count + 1); // Use the unwrapped value */
            };

            let (hasIndex, valueIndex) = vector::index_of(CARD_HIERARCHY, b(value));

            if (!hasIndex) {
                debug::print(b"Error: Card value not found in CARD_HIERARCHY");
            };

            let valueCount = simple_map::borrow(&values, valueIndex);
            if (option::is_none(valueCount)) {
                simple_map::upsert(&mut values, valueIndex, 1);
            } else {
                let unwrapped_count = option::borrow(valueCount);
                simple_map::upsert(&mut values, valueIndex, *unwrapped_count + 1);
            };
            if (value > highestValue) {
                highestValue = value;
            };
            i = i + 1;
        };
        flush = vector::any(vector::values(&suits), |count| {
            count >= 5
        });

        let consecutive: u8 = 0;
        for (idx in 0..13) {
            let hasConsecutive = simple_map::contains_key<u8, u8>(&values, idx);
            if (!hasConsecutive) {
                consecutive = 0;
            } else {
                consecutive = *simple_map::borrow<u8, u8>(&values, idx) + 1;
            };
            if (consecutive >= 5) {
               straight = true;
            }
        };
        vector::for_each<u8>(simple_map::values<u8, u8>(values), |value| {
            if (value == 2) {
                pairs = pairs + 1;
            } else if (value == 3) {
                threeOfAKind = threeOfAKind + 1;
            } else if (value == 4) {
                fourOfAKind = fourOfAKind + 1;
            }
        });
        if (flush && straight) {
            handType = string::utf8(b"Straight Flush");
            handRank = 9;
        } else if (fourOfAKind > 0) {
            handType = string::utf8(b"Four of a Kind");
            handRank = 8;
        } else if (threeOfAKind > 0 && pairs > 0) {
            handType = string::utf8(b"Full House");
            handRank = 7;
        } else if (flush) {
            handType = string::utf8(b"Flush");
            handRank = 6;
        } else if (straight) {
            handType = string::utf8(b"Straight");
            handRank = 5;
        } else if (threeOfAKind > 0) {
            handType = string::utf8(b"Three of a Kind");
            handRank = 4;
        } else if (pairs == 2) {
            handType = string::utf8(b"Two Pair");
            handRank = 3;
        } else if (pairs == 1) {
            handType = string::utf8(b"One Pair");
            handRank = 2;
        };

        (handType, handRank, highestValue)
    }

    fun evaluateHand(game_metadata: &GameMetadata, player: &Player): (string::String, u8, u8) {
        let newCards = vector::empty<Card>();
        vector::append<Card>(&mut newCards, player.hand);
        vector::append<Card>(&mut newCards, game_metadata.community);
        evaluateHandDetails(&newCards)
    }

    // TODO: Add back unit tests

}