import { revealPlayerCard, createCardMapping } from "../../../../../controller/index";
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
    try {

      await createCardMapping(gameId);
    } catch (err) {
      console.log(err);
    }
    const userCards = await revealPlayerCard(
      gameId,
      userPubKey,
      userSignedMessage
    );
    return NextResponse.json({ message: "OK", userCards });
  } catch (err) {
    return NextResponse.json({
      message: err instanceof Error ? err.message : "Application has crashed",
      userCards: [],
    });
  }
}
