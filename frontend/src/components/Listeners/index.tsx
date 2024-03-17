import { useEffect, useState } from "react";
import { getAptosClient } from "../../utils/aptosClient";
import { TransactionWorkerEventsEnum } from "@aptos-labs/ts-sdk";



const aptosClient = getAptosClient();


export function Listeners() {
    const [isLoading, setIsLoading] = useState<boolean>();

    useEffect(() => {
        (async () => {
        const events = await aptosClient.getEvents({
            options: {
              where: {
                account_address: {
                  _eq: "0x0000000000000000000000000000000000000000000000000000000000000000",
                },
                creation_number: {
                  _eq: "0",
                },
                indexed_type: {
                  _eq: "0x2c48a1afc19e2fc88c85d28f7449c9fa6ff22ab7165553fcf50ca32d007366fe::poker_manager::PlayerJoinsGame",
                },
              },
              orderBy: [{
                sequence_number: "asc",
              }],
              limit: 20
            },
          });
          console.log("Listeners mounted")
            console.log(events)
        }
        )();
    }, [aptosClient])

    return <div>
        <h1>Listeners</h1>
    </div>
}