import { NextResponse } from "next/server";
import { createCardMapping } from "../../../../../controller/index";

type ResponseData = {
  message: string;
};

export async function POST(request: Request) {
  try {
    const { gameId } = await request.json();
    createCardMapping(gameId);
    return NextResponse.json({ message: "OK" });
  } catch (err) {
    NextResponse.json({
      message: err instanceof Error ? err.message : "Application has crashed",
    });
  }
}
