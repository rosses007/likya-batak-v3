from datetime import datetime
from typing import List, Optional
from sqlalchemy import String, Integer, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

class Base(DeclarativeBase):
    pass

# 1. Kullanıcı Tablosu
class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    
    # İstatistikler
    elo_rating: Mapped[int] = mapped_column(Integer, default=1000) # Rekabetçi puanlama için
    total_games: Mapped[int] = mapped_column(Integer, default=0)
    total_wins: Mapped[int] = mapped_column(Integer, default=0)
    
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # İlişkiler
    match_scores: Mapped[List["MatchScore"]] = relationship(back_populates="user")


# 2. Oyun (Match) Tablosu
# Bir Batak masasını ve o maçın genel durumunu temsil eder.
class Match(Base):
    __tablename__ = "matches"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    is_multiplayer: Mapped[bool] = mapped_column(Boolean, default=False)
    status: Mapped[str] = mapped_column(String(20), default="completed") # 'waiting', 'in_progress', 'completed'
    
    start_time: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    end_time: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # İlişkiler
    scores: Mapped[List["MatchScore"]] = relationship(back_populates="match")


# 3. Skor ve Performans Tablosu (MatchScore)
# Hangi maçta, hangi kullanıcının ne kadar ihale alıp kaç el kazandığını tutar. (Junction Table)
class MatchScore(Base):
    __tablename__ = "match_scores"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    match_id: Mapped[int] = mapped_column(ForeignKey("matches.id", ondelete="CASCADE"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    
    # O maçtaki performans
    position: Mapped[int] = mapped_column(Integer) # Masa oturuş sırası (0, 1, 2, 3)
    final_score: Mapped[int] = mapped_column(Integer, default=0) # Maç sonu yazboz puanı (Örn: +45, -30)
    is_winner: Mapped[bool] = mapped_column(Boolean, default=False)

    # İlişkiler
    match: Mapped["Match"] = relationship(back_populates="scores")
    user: Mapped["User"] = relationship(back_populates="match_scores")
