import asyncio
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

# Import the ConnectionManager instance
from .websocket_manager import manager
from .match_service import save_match_to_db

router = APIRouter(tags=["Multiplayer"])

@router.websocket("/ws/matchmaking/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect(websocket, client_id)
    try:
        while True:
            data = await websocket.receive_json()
            action_type = data.get("type")
            match_id = data.get("match_id")
            
            if action_type == "play_card":
                match = manager.active_matches.get(match_id)
                if not match:
                    continue

                card_data = data.get("card")
                player_index = data.get("player_index")
                
                # 1. Kartı sunucudaki masaya ekle
                match["table_cards"].append({
                    "player_index": player_index,
                    "suit": card_data["suit"],
                    "rank": card_data["rank"]
                })

                # 2. Atılan kartı anında herkese (kartı atan dahil) yayınla
                await manager.broadcast_to_match({
                    "type": "card_played",
                    "player_index": player_index,
                    "card": card_data
                }, match_id)

                # 3. Yerde 4 kart biriktiyse, eli bitir
                if len(match["table_cards"]) == 4:
                    # Kazananı hesapla
                    winner_index = manager.determine_trick_winner(
                        match["table_cards"], 
                        match["trump_suit"]
                    )
                    
                    # Kazananın el sayısını 1 artır
                    match["tricks_won"][winner_index] += 1
                    
                    # Masayı yeni el için temizle
                    match["table_cards"] = []
                    
                    # Kullanıcıların yerdeki 4 kartı görebilmesi için çok kısa bir bekleme (opsiyonel)
                    await asyncio.sleep(1.5)
                    
                    # Herkese eli kimin aldığını bildir
                    await manager.broadcast_to_match({
                        "type": "round_winner",
                        "winner_index": winner_index,
                        "tricks_won": match["tricks_won"]
                    }, match_id)

                    # Increment trick counter
                    match["tricks_played"] = match.get("tricks_played", 0) + 1

                    # If the match is finished (13 tricks)
                    if match["tricks_played"] >= 13:
                        # Persist results
                        save_match_to_db(match["players"], match["tricks_won"])
                        # Broadcast game over
                        await manager.broadcast_to_match({
                            "type": "game_over",
                            "tricks_won": match["tricks_won"],
                            "message": "Oyun bitti! Skorlar kaydedildi."
                        }, match_id)
                        # Clean up server state
                        if match_id in manager.active_matches:
                            del manager.active_matches[match_id]

    except WebSocketDisconnect:
        await manager.disconnect(client_id)
