const readlineSync = require('readline-sync');
const fs = require('fs');
const gameStateFile = 'gameState.json';
function saveGameState(gameState) {
    fs.writeFileSync(gameStateFile, JSON.stringify(gameState, null, 2), 'utf8');
}
// Simplified Player and Deck initialization for demonstration

function loadGameState() {
    if (fs.existsSync(gameStateFile)) {
        const savedState = fs.readFileSync(gameStateFile, 'utf8');
        return JSON.parse(savedState);
    } else {

        // Initialize a new game state here
        const suits = ['hearts', 'diamonds', 'clubs', 'spades'];
        const values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king', 'ace'];
        const order = Array.from({ length: 52 }, (_, i) => i).map(i => ({ suit: i, value: i }));
        const DECK = suits.map(suit => values.map(value => ({ suit, value }))).flat();
        let gameState = {
            players: [
                { id: 1, hand: [], chips: 1000, currentBet: 0, status: "active", move: 0 },
                { id: 2, hand: [], chips: 1000, currentBet: 0, status: "active", move: 0 },
                { id: 3, hand: [], chips: 1000, currentBet: 0, status: "active", move: 0 },
                { id: 4, hand: [], chips: 1000, currentBet: 0, status: "active", move: 0 }
            ],
            deck: [],
            pot: 0,
            currentBet: 0,
            communityCards: [],
            currentRound: -1, // Use -1 to denote game not started
            stage: "pre-flop",
            currentPlayerIndex: 1,
            continueBetting: true,
            order,
            originalDeck: DECK,
            move: 0,
            lastRaiser: null,
            gameEnded: false
        }
        gameState = initializeDeck(gameState)
        gameState = initializePlayers(4, gameState);
        gameState.currentRound = 0; // Indicates pre-flop
        gameState.dealerPosition = 0; // Dealer position for this hand
        //initializeDeck();
        gameState = collectEntryFees(100, gameState);
        gameState = dealHoleCards(gameState);
        return gameState

    }
}

let gameState = loadGameState();
// Example player setup for demonstration
function initializePlayers(numberOfPlayers, gameState) {
    gameState.players = Array.from({ length: numberOfPlayers }, (_, index) => ({
        id: index + 1,
        chips: 1000, // Starting chips for each player
        hand: [],
        currentBet: 0,
        status: "active", // Can be "active", "folded", "all-in",
        move: 0
    }));
    return gameState;
}

function initializeDeck(gameState) {
    //const suits = ['hearts', 'diamonds', 'clubs', 'spades'];
    //const values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king', 'ace'];
    gameState.deck = []; // Reset the deck
    gameState.order.forEach(({ suit, value }) => {
        gameState.deck.push({ suit, value });
    })

    shuffleDeck(gameState.deck); // Shuffle the deck after initialization
    return gameState;
}

const revealCards = () => {
    gameState.deck.forEach((i, card) => {
        const { _, value } = card;
        gameState.deck[i] = { suit: gameState.originalDeck[i.suit].suit, value: gameState.originalDeck[i.suit].value };
    })
}

const revealCard = (hand) => {
    if (Array.isArray(hand)) {
        return hand.map(i => ({ suit: gameState.originalDeck[i.suit].suit, value: gameState.originalDeck[i.suit].value }))
    }
    else {
        return ({ suit: gameState.originalDeck[hand.suit].suit, value: gameState.originalDeck[hand.suit].value });
    }
}

function shuffleDeck(deck) {
    for (let i = deck.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [deck[i], deck[j]] = [deck[j], deck[i]]; // Swap
    }
}


function dealHoleCards(gameState) {
    gameState.players.forEach(player => {
        player.hand = [gameState.deck.pop(), gameState.deck.pop()]; // Deal two cards to each player
    });
    return gameState;
}

const seed = Math.floor(Math.random() * 52);
function dealCommunityCards(number) {
    // Ensure the function doesn't attempt to deal more cards than what remains in the deck
    if (number > gameState.deck.length) {
        console.error("Not enough cards in the deck to deal the requested number of community cards.");
        return;
    }

    for (let i = 0; i < number; i++) {
        // Remove the top card from the deck and add it to the community cards
        const card = gameState.deck.pop((i + seed) % 52); // Takes the last card from the deck
        gameState.communityCards.push(card); // Adds it to the community cards
    }
}



function collectEntryFees(entryFee, gameState) {
    gameState.players.forEach(player => {
        if (player.chips >= entryFee) {
            player.chips -= entryFee; // Deduct the entry fee from the player's chips
            gameState.pot += entryFee; // Add the entry fee to the pot
        } else {
            console.error(`Player ${player.id} does not have enough chips to enter the game.`);
            // Handle the case where a player cannot afford the entry fee
            // This could involve removing the player from the game or handling it otherwise
        }
    });
    return gameState;
}

function distributePot(winnerId) {
    const winner = gameState.players.find(p => p.id === winnerId);
    winner.chips += gameState.pot;
    console.log(`Player ${winnerId} wins the pot of $${gameState.pot}.`);

    // Reset pot for the next hand
    gameState.pot = 0;
}




function evaluateHandDetails(cardsArr) {
    let suits = {}, values = {};
    let straight = false, flush = false, highestValue = 0;
    let pairs = 0, threeOfAKind = 0, fourOfAKind = 0
    let bestCombinationHighestValue = Array(9).fill(0).reduce((acc, _, i) => ({ ...acc, [i + 1]: [] }), {});
    cardsArr.forEach(card => {
        if (!suits[card.suit]) suits[card.suit] = 1;
        else suits[card.suit]++;

        let valueIndex = cardHeirarchy.indexOf(card.value);

        if (!values[valueIndex]) values[valueIndex] = 1;
        else values[valueIndex]++;

        highestValue = Math.max(highestValue, valueIndex);
    });

    flush = Object.values(suits).some(count => count >= 5);
    if (flush) {
        bestCombinationHighestValue[6] = [highestValue]
    }
    let consecutive = 0;
    for (let i = 0; i < 13; i++) {
        consecutive = values[i] && values[12] || values[i] ? consecutive + 1 : 0;
        if (consecutive >= 5) {
            bestCombinationHighestValue[5] = [i]
            straight = true
        };
    }

    Object.entries(values).forEach(([value, count]) => {
        if (count === 2) {
            if (pairs === 1) {
                const handRank = 3;
                bestCombinationHighestValue[handRank].push(bestCombinationHighestValue[2].pop());
                bestCombinationHighestValue[handRank].push(value);
                pairs++
            } else {
                const handRank = 2;
                bestCombinationHighestValue[handRank].push(value);
                pairs++
            }

        };
        if (count === 3) {
            const handRank = 4;
            bestCombinationHighestValue[handRank].push(value);
            threeOfAKind++
        };
        if (count === 4) {
            const handRank = 8;
            bestCombinationHighestValue[handRank].push(value);
            fourOfAKind++
        };
    });

    let handType = "High Card", handRank = 1;
    if (straight && flush) { handType = "Straight Flush"; handRank = 9; }
    else if (fourOfAKind) { handType = "Four of a Kind"; handRank = 8; }
    else if (threeOfAKind && pairs >= 1) { handType = "Full House"; handRank = 7; }
    else if (flush) { handType = "Flush"; handRank = 6; }
    else if (straight) { handType = "Straight"; handRank = 5; }
    else if (threeOfAKind) { handType = "Three of a Kind"; handRank = 4; }
    else if (pairs === 2) { handType = "Two Pair"; handRank = 3; }
    else if (pairs === 1) { handType = "One Pair"; handRank = 2; }

    return { handType, handRank, comparisonValue: highestValue, bestCombinationHighestValue };
}
const cardHeirarchy = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king', 'ace'];

function evaluateHand(cardsArr) {
    // Find the player and their current hand
    //const player = gameState.players.find(p => p.id === playerId);
    // const playerCards = [{ value: "3", suit: "diamonds" }, { value: "4", suit: "diamonds" }]
    // const cardsArr = [{ value: "6", suit: "spades" }, { value: "2", suit: "diamonds" }, { value: "7", suit: "diamonds" }, { value: "8", suit: "diamonds" }, { value: "10", suit: "spades" }, ...playerCards] // Combine player's hand with community cards

    // Pass the combined array of cards to evaluateHandDetails for evaluation
    let handEvaluation = evaluateHandDetails(cardsArr);

    // Return the evaluation results
    return handEvaluation;
}


const evaluateWinnerWithSameHandRank = (player1, player2, handRank) => {
    const { bestCombinationHighestValue: bestCombinationHighestValue1, handRank: handRank1, comparisonValue: comparisonValue1 } = player1.evaluation;
    const { bestCombinationHighestValue: bestCombinationHighestValue2, handRank: handRank2, comparisonValue: comparisonValue2 } = player2.evaluation;
    console.log(bestCombinationHighestValue1[handRank].length)
    if (handRank === "7") {
        bestCombinationHighestValue1[handRank] = [bestCombinationHighestValue1["2"].pop(), bestCombinationHighestValue1["4"].pop()]
        bestCombinationHighestValue2[handRank] = [bestCombinationHighestValue2["2"].pop(), bestCombinationHighestValue2["4"].pop()]
    }
    else if (handRank === "9") {
        bestCombinationHighestValue1[handRank] = [bestCombinationHighestValue1["5"].pop(), bestCombinationHighestValue1["6"].pop()]
        bestCombinationHighestValue2[handRank] = [bestCombinationHighestValue2["5"].pop(), bestCombinationHighestValue2["6"].pop()]
    }
    if (bestCombinationHighestValue1[handRank].slice(-1) > bestCombinationHighestValue2[handRank].slice(-1)) {
        return player1
    }
    else if (bestCombinationHighestValue1[handRank].slice(-1) < bestCombinationHighestValue2[handRank].slice(-1)) {
        return player2
    }
    else if (bestCombinationHighestValue1[handRank].length > 1 && bestCombinationHighestValue2[handRank].length > 1) {
        if (bestCombinationHighestValue1[handRank].slice(-2) > bestCombinationHighestValue2[handRank].slice(-2)) {
            return player1
        }
        else if (bestCombinationHighestValue1[handRank].slice(-2) < bestCombinationHighestValue2[handRank].slice(-2)) {
            return player2
        }
    }
    if (comparisonValue1 > comparisonValue2) {
        return player1
    }
    else if (comparisonValue1 < comparisonValue2) {
        return player2
    }
    else {
        return "Draw"
    }
}


function finalEvaluationAndWinnerDetermination() {
    // const playerCards = [{ value: "3", suit: "diamonds" }, { value: "4", suit: "diamonds" }]
    // const cardsArr = [{ value: "6", suit: "spades" }, { value: "2", suit: "diamonds" }, { value: "7", suit: "diamonds" }, { value: "8", suit: "diamonds" }, { value: "10", suit: "spades" }, ...playerCards] // Combine player's hand with community cards
    const community = [{ value: "6", suit: "spades" },
    { value: "6", suit: "diamonds" },
    { value: "7", suit: "diamonds" },
    { value: "8", suit: "diamonds" },
    { value: "9", suit: "diamonds" }]
    const players = [{ status: "active", id: 0, hand: [...community, { value: "6", suit: "diamonds" }, { value: "6", suit: "clubs" }] },
    { status: "active", id: 1, hand: [...community, { value: "10", suit: "diamonds" }, { value: "7", suit: "clubs" }] },
    { status: "activ", id: 2 },
    { status: "activ", id: 3 }];
    let evaluations =
        players.filter(player => player.status === "active")
            .map(player => ({
                playerId: player.id,
                evaluation: evaluateHand(player.hand),
            }));

    let winners = [];
    for (const evaluation of evaluations.slice(1)) {
        if (!winners.length) {
            winners.push(evaluations[0])
        }
        console.log(evaluation.playerId)
        for (const prevWinner of winners) {
            if (prevWinner.evaluation.handRank === evaluation.evaluation.handRank) {
                if (prevWinner.playerId === evaluation.playerId) {
                    break
                }

                const winner = evaluateWinnerWithSameHandRank(prevWinner, evaluation, `${evaluation.evaluation.handRank}`)
                if (winner === "Draw") {
                    winners.push(evaluation)
                }
                else {
                    winners = [winner]
                }
            } else if (prevWinner.evaluation.handRank < evaluation.evaluation.handRank) {
                winners = [evaluation]
            }
        }
        // 1 --> 2 --> Draw --> 3 ---> 3 -> 1 = 3
        //distributePot(winner.playerId);

    }
    gameState.gameEnded = true;
    console.log(JSON.stringify(winners));
}

function nextRound() {
    gameState.currentRound++;
    switch (gameState.currentRound) {
        case 1:
            console.log("Dealing the flop...");
            dealCommunityCards(3);
            console.log(gameState.communityCards)
            gameState.stage = "flop";
            break;
        case 2:
            console.log("Dealing the turn...");
            dealCommunityCards(1);
            gameState.stage = "turn";
            console.log(gameState.communityCards)
            break;
        case 3:
            console.log("Dealing the river...");
            dealCommunityCards(1);
            gameState.stage = "river";
            console.log(gameState.communityCards)
            break;
        case 4:
            console.log("Showdown.");
            revealCards();
            finalEvaluationAndWinnerDetermination();
            console.log(revealCard(gameState.communityCards))
            gameState.stage = "showdown";
            return; // End the game loop after showdown
    }
    // Start a betting round after dealing cards (except for the showdown)
    // if (gameState.currentRound < 4) {
    //     startBettingRound();
    // }
}

function playerAction(playerIndex, move) {
    let player = gameState.players[playerIndex];
    if (player.status === "active") {
        console.log(`Player ${player.id}'s turn. Your hand:`, revealCard(player.hand).map(card => `${card.value} of ${card.suit}`).join(', '));
        let action = readlineSync.question('Enter your action (raise <value>/call/fold): ');

        if (action.startsWith('raise')) {
            const value = parseInt(action.split(' ')[1]);
            if (isNaN(value) || player.chips < value) {
                throw new Error('Invalid raise amount.');
            }
            player.chips -= value;
            gameState.pot += value;
            gameState.currentBet = value;
            console.log(`Player ${player.id} raises by $${value}.`);
            gameState.lastRaiser = { playerIndex, move }; // Update last raiser
            gameState.dealerPosition = playerIndex - 1; // Update dealer position
        } else if (action === 'call') {
            if (gameState.lastRaiser === null) {
                throw new Error('No bet to call.');

            }
            const callAmount = gameState.currentBet - +player.currentBet;
            if (player.chips < callAmount) {
                throw new Error('Not enough chips to call.');
            }
            player.chips -= callAmount;
            gameState.pot += callAmount;
            player.currentBet += callAmount;
            console.log(`Player ${player.id} calls.`);
        } else if (action === 'fold') {
            player.status = "folded";
            console.log(`Player ${player.id} folds.`);
        } else {
            console.log('Invalid action.');
            return { valid: false, gameState }; // Invalid action, ask again
        }
    }
    return { valid: true, gameState } // Valid action
}

function startBettingRound() {

    //gameState.currentPlayerIndex = (gameState.dealerPosition + 1) % gameState.players.length; // Start with the player next to the dealer
    if (gameState.continueBetting) {
        const activePlayer = gameState.players[gameState.currentPlayerIndex];
        const activePlayers = gameState.players.filter(p => p.status === "active");
        if (activePlayers.length === 1 || (gameState.lastRaiser !== null && gameState.lastRaiser.playerIndex === gameState.currentPlayerIndex && activePlayer.move != gameState.lastRaiser.move)) {
            gameState.continueBetting = false; // End the round
            //gameState.currentPlayerIndex = (gameState.currentPlayerIndex + 1) % gameState.players.length;
            gameState.lastRaiser = null
            return gameState
        }
        const action = playerAction(gameState.currentPlayerIndex, activePlayer.move);
        activePlayer.move += 1
        gameState = action.gameState;
        if (!action.valid) {
            // If the action was invalid, repeat the prompt for the same player
            return gameState

        }

        // Check if the round should end: if everyone called the last raise or if only one player is left
        //gameState.players[gameState.currentPlayerIndex] = activePlayer;
        gameState.currentPlayerIndex = (gameState.currentPlayerIndex + 1) % gameState.players.length; // Move to the next player
        console.log(`Pot: $${gameState.pot}, current player: ${gameState.currentPlayerIndex}`);

    }
    return gameState
}


// function startGame() {
//     const state = startBettingRound(); // Initiate the first betting round
//     if (!gameState.continueBetting) {
//         // Proceed to the next game stage after betting round ends
//         nextRound();
//         gameState.continueBetting = true; // Reset continueBetting for the next round
//     }
//     saveGameState(state);
// }

// startGame();

finalEvaluationAndWinnerDetermination()