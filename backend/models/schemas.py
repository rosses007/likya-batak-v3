from pydantic import BaseModel
from typing import List

# Gelen skor verisi modeli
class PlayerScoreCreate(BaseModel):
    user_id: int
    position: int
    final_score: int
    is_winner: bool

# Gelen maç sonu verisi ana modeli
class MatchCreate(BaseModel):
    is_multiplayer: bool
    scores: List[PlayerScoreCreate]

# Liderlik tablosunda dönecek kullanıcı modeli
class LeaderboardResponse(BaseModel):
    username: str
    elo_rating: int
    total_wins: int
    total_games: int
    
    class Config:
        from_attributes = True # SQLAlchemy modellerini otomatik Pydantic formatına çevirmek için
