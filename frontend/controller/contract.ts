import { getAptosClient } from "../src/utils/aptosClient";


const client = getAptosClient()
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || "0x7436bbe16422c873f3d81bf1668b96ef50f2c6624a851c1a991c92de1b253b29"

export const getGameById = async (gameId: number) => {
    return await client.view({
        payload: {
            function: `${CONTRACT_ADDRESS}::poker_manager::get_game_by_id`,
            functionArguments: [gameId]
        }}
    )
}