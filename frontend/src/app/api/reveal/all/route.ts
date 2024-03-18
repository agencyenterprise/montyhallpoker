import { NextResponse } from "next/server";
import { revealGameCards } from "../../../../../controller/transaction";

export async function POST(request: Request) {
    try {
        const { gameId } = await request.json();
        if (!gameId) {
            return NextResponse.json({
                message:
                    "Attributes missing on the payload. Please send gameId",
                userCards: [],
            });
        }
        const userCards = await revealGameCards(gameId);
        return NextResponse.json({ message: "OK", userCards });
    } catch (err) {
        return NextResponse.json({
            message: err instanceof Error ? err.message : "Application has crashed",
            userCards: [],
        });
    }
}
