import uuid
import random
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[str, WebSocket] = {}
        self.waiting_lobby: list[str] = []
        
        # Artık sadece oyuncuları değil, masanın o anki tüm durumunu tutuyoruz
        self.active_matches: dict[str, dict] = {}

    # ... (connect, disconnect, send_personal_message, broadcast_to_match metodları aynı kalacak) ...

    async def check_matchmaking(self):
        if len(self.waiting_lobby) >= 4:
            players_for_match = [self.waiting_lobby.pop(0) for _ in range(4)]
            match_id = str(uuid.uuid4())
            
            # Maçın başlangıç durumunu (State) oluştur
            self.active_matches[match_id] = {
                "players": players_for_match,
                "table_cards": [],         # O el yere atılan kartlar: {"player_index": int, "suit": int, "rank": int}
                "tricks_won": [0, 0, 0, 0], # 4 oyuncunun aldığı el sayıları
                "trump_suit": 0,            # Şimdilik varsayılan koz Maça (0). İhale sisteminde güncellenir.
                "tricks_played": 0  # YENİ SAYAÇ
            }
            
            deck = [{"suit": s, "rank": r} for s in range(4) for r in range(13)]
            random.shuffle(deck)
            hands = [deck[i * 13 : (i + 1) * 13] for i in range(4)]

            for index, p_id in enumerate(players_for_match):
                await self.send_personal_message({
                    "type": "game_start",
                    "match_id": match_id,
                    "position": index,
                    "players": players_for_match,
                    "hand": hands[index],
                    "turn_index": 0 
                }, p_id)

    def determine_trick_winner(self, table_cards: list, trump_suit: int) -> int:
        """4 kart atıldığında Batak kurallarına göre kazanan indeksini bulur"""
        lead_suit = table_cards[0]['suit']
        winning_card = table_cards[0]
        winner_index = table_cards[0]['player_index']

        for card in table_cards[1:]:
            # DURUM 1: Atılan kart Koz ise
            if card['suit'] == trump_suit:
                # Masadaki kazanan kart koz değilse (ilk koz düşmüşse)
                if winning_card['suit'] != trump_suit:
                    winning_card = card
                    winner_index = card['player_index']
                # Masadaki kazanan da kozsa, büyük olan kazanır
                elif card['rank'] > winning_card['rank']:
                    winning_card = card
                    winner_index = card['player_index']
            
            # DURUM 2: Atılan kart yerdeki ilk renkle aynıysa
            elif card['suit'] == lead_suit:
                # Kazanan kart koz değilse ve atılan kart kazanandan büyükse
                if winning_card['suit'] != trump_suit and card['rank'] > winning_card['rank']:
                    winning_card = card
                    winner_index = card['player_index']

        return winner_index


manager = ConnectionManager()
