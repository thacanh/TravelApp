from sqlalchemy import Column, Integer, String, Float, DateTime, JSON, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from ..database import Base


class Location(Base):
    __tablename__ = "locations"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False, index=True)
    description = Column(Text, nullable=True)
    category = Column(String(50), nullable=False)  # beach, mountain, city, cultural, etc.
    address = Column(String(500), nullable=True)
    city = Column(String(100), nullable=False, index=True)
    country = Column(String(100), default="Vietnam")
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    rating_avg = Column(Float, default=0.0)
    total_reviews = Column(Integer, default=0)
    images = Column(JSON, default=list)  # List of image URLs
    description_embedding = Column(JSON, nullable=True)  # Embedding vector from Gemini embedding-001
    created_by = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    reviews = relationship("Review", back_populates="location", cascade="all, delete-orphan")
    favorites = relationship("Favorite", back_populates="location", cascade="all, delete-orphan")
    category_links = relationship("LocationCategory", back_populates="location", cascade="all, delete-orphan")
    categories = relationship("Category", secondary="location_categories", viewonly=True)
