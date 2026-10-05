from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

# Import your SQLAlchemy session factory (engine) and models
# Adjust the import path according to your project structure
# from .database import SessionLocal
# from . import models

# For this snippet we assume `SessionLocal` and `models` are available in the
# same package (backend). If they are in a different module, modify the import
# accordingly.

def save_match_to_db(players: list[str], tricks_won: list[int]) -> None:
    """Persist a completed multiplayer match and its scores.

    Args:
        players (list[str]): List of client IDs (or user IDs) that participated.
        tricks_won (list[int]): Number of tricks each player won, aligned with
            the ``players`` list order.
    """
    if len(players) != len(tricks_won):
        raise ValueError("players and tricks_won must have the same length")

    # Determine the winner – first player with the highest trick count.
    max_tricks = max(tricks_won)
    winner_index = tricks_won.index(max_tricks)

    # Open a DB session; the context manager ensures it is closed properly.
    try:
        with SessionLocal() as db:  # type: Session
            # Create the Match row.
            new_match = models.Match(
                is_multiplayer=True,
                status="completed",
            )
            db.add(new_match)
            db.flush()  # Assigns an ID without committing yet.

            # Insert a MatchScore row for each participant.
            for i, client_id in enumerate(players):
                # Convert client_id to int if possible; fall back to a generic user.
                try:
                    user_id = int(client_id)
                except (ValueError, TypeError):
                    user_id = 1  # Anonymous / default user.

                is_winner = i == winner_index
                final_score = tricks_won[i] * 10  # Simple scoring rule.

                match_score = models.MatchScore(
                    match_id=new_match.id,
                    user_id=user_id,
                    position=i,
                    final_score=final_score,
                    is_winner=is_winner,
                )
                db.add(match_score)

                # Update user statistics if the user exists.
                user = db.query(models.User).filter(models.User.id == user_id).first()
                if user:
                    user.total_games += 1
                    if is_winner:
                        user.total_wins += 1
                        user.elo_rating += 15
                    else:
                        # Prevent negative Elo.
                        user.elo_rating = max(0, user.elo_rating - 5)

            db.commit()
            print(f"Çok oyunculu maç başarıyla kaydedildi. Maç ID: {new_match.id}")
    except SQLAlchemyError as e:
        # If something goes wrong, roll back the transaction and surface the error.
        print(f"Veritabanına kaydetme hatası: {e}")
        raise
