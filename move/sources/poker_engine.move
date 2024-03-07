module poker::poker_engine {
    use std::vector;
    use std::string;
    use std::option;
    use std::simple_map::{SimpleMap,Self};
    use poker::poker_manager::GameMetadata;
    use poker::poker_manager::Hand;
    use aptos_std::randomness;
    use aptos_std::debug;
    const cardHierarchy: vector<string::String> = vector[string::utf8(b"2"), string::utf8(b"3"), string::utf8(b"4"), string::utf8(b"5"), string::utf8(b"6"), string::utf8(b"7"), string::utf8(b"8"), string::utf8(b"9"), string::utf8(b"10"), string::utf8(b"jack"), string::utf8(b"queen"), string::utf8(b"king"), string::utf8(b"ace")];

    fun initializeDeck(GameMetadata: &mut GameMetadata) {
        let suits = vector[0, 1, 2, 3]; // 0 = hearts, 1 = diamonds, 2 = clubs, 3 = spades
        let values = vector[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
        
        let i = 0;
        while (i < vector::length(&suits)) {
            let suit = vector::borrow(&suits, i);
            let j = 0;
            while (j < vector::length(&values)) {
                let value = vector::borrow(&values, j);
                vector::push_back(&mut GameMetadata.deck, Hand {
                    suit: suit,
                    value: value,
                    suit_string: string::new(),
                    value_string: string::new()
                });
                j = j + 1;
            };
            i = i + 1;
        };

        GameMetadata.seed = randomness::u8_range(0, 51);
    }
    
    fun initializePlayers(GameMetadata: &GameMetadata, players: &vector<address>) {
        let i = 0;
        while (i < vector::length(players)) {
            let player = vector::borrow(players, i);
            vector::push_back(&mut GameMetadata.players, Player{id: *player, hand: vector::new()});
            i = i + 1;
        };
    }

    fun dealHoleCards(GameMetadata: &GameMetadata) {
        let i = 0;
        while (i < vector::length(&GameMetadata.players)) {
            let player = vector::borrow_mut(&GameMetadata.players, i);
            vector::push_back(&mut player.hand, vector::pop_back(&mut GameMetadata.deck));
            vector::push_back(&mut player.hand, vector::pop_back(&mut GameMetadata.deck));
            i = i + 1;
        };
    }

    fun evaluateHandDetails(cards: &vector<Hand>): (u8, u8, u8, u8, u8) {
        let hand = Hand{suit: 0, value: 0, suit_string: b"", value_string: b""};
        let straight: bool = false
        let flush: bool = false
        let handType: string::String = string::utf8(b"High Card");
        let handRank: u8 = 1;
        let highestValue: u8 = 0;
        let pairs: u8 = 0
        let threeOfAKind: u8 = 0
        let fourOfAKind: u8 = 0
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

            let (hasIndex, valueIndex) = vector::index_of(cardHierarchy, value);

            if (!hasIndex) {
                debug::print(b"Error: Card value not found in cardHierarchy");
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
        flush = vector::any(suits.values(), |count| {
            count >= 5
        });

        let consecutive: u8 = 0;
        for idx in 0..13 {
            const hasConsecutive = simple_map::contains_key<u8>(&values, idx);
            if (!hasConsecutive) {
                consecutive = 0;
            } else {
                consecutive = *simple_map::borrow<u8>(&values, idx) + 1;
            }
            if (consecutive >= 5) {
               straight = true;
            }
        }
        vector::for_each(values.values(), |value| {
            if (value == 2) {
                pairs += 1;
            } else if (value == 3) {
                threeOfAKind += 1;
            } else if (value == 4) {
                fourOfAKind += 1;
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
        } else if pairs == 2 {
            handType = string::utf8(b"Two Pair");
            handRank = 3;
        } else if pairs == 1 {
            handType = string::utf8(b"One Pair");
            handRank = 2;
        }

        (handType, handRank, highestValue)
    }

    fun evaluateHand(GameMetadata: &GameMetadata, player: &Player): (string::String, u8, u8) {
        let newCards = vector::new<Hand>()
        vector::append(&newCards, &player.hand);
        vector::append(&newCards, &GameMetadata.communityCards);
        evaluateHandDetails(&newCards)
    }


}