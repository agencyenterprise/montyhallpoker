import { connectToDatabase } from "./mongodb"

type CardValueMapping = Record<number, string>
type SuitValueMapping = Record<number, string>
type Hand = {suit: string, value: string}

export const getGameMapping = async (gameId: number) => {
    const {db} = await connectToDatabase()
    const mappings = db.collection("mappings")
    return await mappings.findOne({gameId});
}



export const insertCardMapping = async (gameId: number, valueMapping: CardValueMapping, suitMapping: SuitValueMapping) => {
    const gameMapping = await getGameMapping(gameId)
    if (!gameMapping) {
        const {db} = await connectToDatabase()
        const mappings = db.collection("mappings")
        return await mappings.insertOne({gameId, valueMapping, suitMapping})
    }
    return gameMapping
}


export const revealCard = async (gameId: number, value: number, suit: number): Promise<Hand> => {
    const gameMapping = await getGameMapping(gameId)
    if (!gameMapping) {
        throw new Error("No game found!")
    }
    const {valueMapping, suitMapping} = gameMapping
    const privateHandValue = valueMapping[value]
    const privateHandSuit = suitMapping[suit]
    if (!privateHandValue || !privateHandSuit) {
        throw new Error("Invalid suit or value index")
    }
    return {value: privateHandValue, suit: privateHandSuit}
}