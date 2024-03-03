module poker::poker_engine {
    use std::vector;
    use std::string;
    use std::option;
    use std::simple_map::{SimpleMap,Self};
    use poker::poker_engine::poker_engine::GameMetadata;
    use poker::poker_engine::poker_engine::Hand;
    use aptos_std::randomness;
    use aptos_std::debug;
    const cardHeirarchy: vector<string::String> = [string::utf8(b"2"), string::utf8(b"3"), string::utf8(b"4"), string::utf8(b"5"), string::utf8(b"6"), string::utf8(b"7"), string::utf8(b"8"), string::utf8(b"9"), string::utf8(b"10"), string::utf8(b"jack"), string::utf8(b"queen"), string::utf8(b"king"), string::utf8(b"ace")];
    fun initializeDeck(GameMetadata: &GameMetadata): u8 {
        let suits = [0, 1, 2, 3]; // 0 = hearts, 1 = diamonds, 2 = clubs, 3 = spades
        let values = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
        for suit in suits.iter() {
            for value in values.iter() {
                GameMetadata.deck.push(Hand{suit: *suit, value: *value, suit_string: string::new(), value_string: string::new()});
            }
        }
        GameMetadata.seed = randomness::u8_range(0, 51)
    }
    fun initializePlayers(GameMetadata: &GameMetadata, players: &vector<address>) {
        for player in players.iter() {
            GameMetadata.players.push(Player{id: *player, hand: vector::new()});
        }
    }
    fun dealHoleCards(GameMetadata: &GameMetadata) {
        for player in GameMetadata.players.iter() {
            player.hand.push(GameMetadata.deck.pop());
            player.hand.push(GameMetadata.deck.pop());
        }
    }
    fun evaluateHandDetails(cards: &vector<Hand>) -> (u8, u8, u8, u8, u8) {
        let hand = Hand{suit: 0, value: 0, suit_string: b"", value_string: b""};
        let handRank = 0;
        let highCard = 0;
        let secondHighCard = 0;
        let thirdHighCard = 0;
        let fourthHighCard = 0;
        let fifthHighCard = 0;
        let suits: SimpleMap<string::String, u8> = simple_map::new();
        let values = SimpleMap<u8, u8> = simple_map::new();
        let highestValue: u8 = 0;
        for card in cards.iter() {
            let suit = card.suit_string;
            let value = card.value_string;
            let suitCount = suits.get(suit);
            
            match suitCount {
                option::none {
                    suits.insert(suit, 1);
                }
                option::some {
                    suits.insert(suit, suitCount + 1);
                }
            }
            let (hasIndex, valueIndex) = cardHeirarchy.index_of(value);
            if !hasIndex {
                debug::log("Error: Card value not found in cardHeirarchy");
            }
            let valueCount = values.get(valueIndex);
            match valueCount {
                option::none {
                    values.insert(valueIndex, 1);
                }
                option::some {
                    values.insert(valueIndex, valueCount + 1);
                }
            }
            if value > highestValue {
                highestValue = value;
            }
        }
        flush = vector::any(suits.values(), |count| {
            count >= 5
        });
        let consecutive: u8 = 0;
        for card in cardHeirarchy.iter() {
            let cardIdx = cardHeirarchy.index_of(card);
            let valueCount = values.get(cardIdx);
            match valueCount {
                option::none {
                    consecutive = 0;
                }
                option::some {
                    consecutive += 1;
                    if consecutive >= 5 {
                        break;
                    }
                }
            }
        }
        vector::for_each(cardHeirarchy, || {
            let value = values.get(card);
            match value {
                option::none {
                    ()
                }
                option::some {
                    if value > highCard {
                        fifthHighCard = fourthHighCard;
                        fourthHighCard = thirdHighCard;
                        thirdHighCard = secondHighCard;
                        secondHighCard = highCard;
                        highCard = value;
                    } else if value > secondHighCard {
                        fifthHighCard = fourthHighCard;
                        fourthHighCard = thirdHighCard;
                        thirdHighCard = secondHighCard;
                        secondHighCard = value;
                    } else if value > thirdHighCard {
                        fifthHighCard = fourthHighCard;
                        fourthHighCard = thirdHighCard;
                        thirdHighCard = value;
                    } else if value > fourthHighCard {
                        fifthHighCard = fourthHighCard;
                        fourthHighCard = value;
                    } else if value > fifthHighCard {
                        fifthHighCard = value;
                    }
                }
            }
        });
    }


}