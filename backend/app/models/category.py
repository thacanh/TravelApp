from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from ..database import Base


class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    slug = Column(String(50), unique=True, index=True, nullable=False)
    name = Column(String(100), nullable=False)
    icon = Column(String(50), nullable=True)  # Optional icon name for mobile app

    # Relationships
    location_links = relationship("LocationCategory", back_populates="category", cascade="all, delete-orphan")
    locations = relationship("Location", secondary="location_categories", viewonly=True)


class LocationCategory(Base):
    __tablename__ = "location_categories"

    location_id = Column(Integer, ForeignKey("locations.id", ondelete="CASCADE"), primary_key=True)
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="CASCADE"), primary_key=True)

    # Relationships
    location = relationship("Location", back_populates="category_links")
    category = relationship("Category", back_populates="location_links")
