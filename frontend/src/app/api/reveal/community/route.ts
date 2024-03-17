import { NextResponse } from "next/server";
import {
  revealCommunityCards,
  revealPlayerCard,
} from "../../../../../controller/index";

export async function POST(request: Request) {
  let userCards: any[] = [];
  try {
    const { gameId, userPubKey, userSignedMessage } = await request.json();
    if (!gameId) {
      return NextResponse.json({
        message: "gameId missing",
        communityCards: [],
        userCards,
      });
    }
    const communityCards = await revealCommunityCards(gameId);
    if (userPubKey && userSignedMessage) {
      userCards = await revealPlayerCard(gameId, userPubKey, userSignedMessage);
    }

    return NextResponse.json({ message: "OK", communityCards, userCards });
  } catch (err) {
    return NextResponse.json({
      message: err instanceof Error ? err.message : "Application has crashed",
      communityCards: [],
      userCards,
    });
  }
}
