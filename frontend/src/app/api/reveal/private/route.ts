import { revealPlayerCard } from "../../../../../controller/index";
import { NextResponse } from "next/server";

export async function POST(request: Request) {
  try {
    const { gameId, userPubKey, userSignedMessage } = await request.json();
    if (!gameId || !userPubKey || !userSignedMessage) {
      return NextResponse.json({
        message:
          "Attributes missing on the payload. Please send gameId, userPubKey and userSignedMessage",
        userCards: [],
      });
    }
    const userCards = await revealPlayerCard(
      gameId,
      userPubKey,
      userSignedMessage
    );
    return NextResponse.json({ message: "OK", userCards });
  } catch (err) {
    NextResponse.json({
      message: err instanceof Error ? err.message : "Application has crashed",
      userCards: [],
    });
  }
}
