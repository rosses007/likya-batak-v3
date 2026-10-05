from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from typing import List

import models
import schemas
# get_db fonksiyonunun database.py gibi bir dosyadan geldiğini varsayıyoruz
# from database import get_db 

router = APIRouter(tags=["Matches"])

@router.post("/matches/score")
def save_match_score(match_data: schemas.MatchCreate, db: Session = Depends(get_db)):
    """
    Oyun bittiğinde Flutter'dan gelen maç ve skor verilerini veritabanına kaydeder.
    Kullanıcıların toplam maç, kazanma ve ELO puanlarını günceller.
    """
    # 1. Yeni Maç Kaydını Oluştur
    new_match = models.Match(
        is_multiplayer=match_data.is_multiplayer,
        status="completed",
        end_time=datetime.utcnow()
    )
    db.add(new_match)
    db.commit()
    db.refresh(new_match) # Oluşan maçın ID'sini almak için refresh ediyoruz

    # 2. Her bir oyuncunun skorunu MatchScore tablosuna ekle ve User istatistiklerini güncelle
    for score in match_data.scores:
        new_score = models.MatchScore(
            match_id=new_match.id,
            user_id=score.user_id,
            position=score.position,
            final_score=score.final_score,
            is_winner=score.is_winner
        )
        db.add(new_score)

        # Kullanıcı istatistiklerini güncelle (ELO Sistemi)
        user = db.query(models.User).filter(models.User.id == score.user_id).first()
        if user:
            user.total_games += 1
            if score.is_winner:
                user.total_wins += 1
                user.elo_rating += 15  # Kazanan 15 ELO puanı alır
            else:
                # Kaybedenden 5 puan düşer, ancak 0'ın altına inmemesi sağlanır
                user.elo_rating = max(0, user.elo_rating - 5)

    # 3. Tüm işlemleri tek seferde veritabanına işle
    db.commit()

    return {"message": "Maç skorları başarıyla kaydedildi.", "match_id": new_match.id}


@router.get("/leaderboard", response_model=List[schemas.LeaderboardResponse])
def get_leaderboard(limit: int = 10, db: Session = Depends(get_db)):
    """
    ELO puanı en yüksek olan oyuncuları azalan (descending) sırada getirir.
    Flutter tarafında Ana Ekran'da gösterilmek için kullanılır.
    """
    users = db.query(models.User)\
              .order_by(models.User.elo_rating.desc())\
              .limit(limit)\
              .all()
    return users
