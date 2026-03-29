from typing import List, Optional
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from ..models import Location, Review, Favorite, Category, LocationCategory
from ..schemas.location import LocationCreate, LocationUpdate


class LocationService:
    @staticmethod
    def get_location(db: Session, location_id: int) -> Optional[Location]:
        """Get location by ID"""
        return db.query(Location).options(joinedload(Location.categories)).filter(Location.id == location_id).first()
    
    @staticmethod
    def get_locations(
        db: Session,
        skip: int = 0,
        limit: int = 20,
        category: Optional[str] = None,
        city: Optional[str] = None,
        search: Optional[str] = None,
        min_rating: Optional[float] = None
    ) -> List[Location]:
        """Get locations with filters"""
        query = db.query(Location).options(joinedload(Location.categories))
        
        if category:
            query = query.join(Location.categories).filter(Category.slug == category)
        
        if city:
            query = query.filter(Location.city == city)
        
        if search:
            query = query.filter(
                (Location.name.ilike(f"%{search}%")) | 
                (Location.description.ilike(f"%{search}%"))
            )
        
        if min_rating:
            query = query.filter(Location.rating_avg >= min_rating)
        
        return query.order_by(Location.rating_avg.desc()).offset(skip).limit(limit).all()
    
    @staticmethod
    def create_location(db: Session, location: LocationCreate) -> Location:
        """Create new location"""
        db_location = Location(**location.model_dump())
        db.add(db_location)
        db.commit()
        db.refresh(db_location)
        return db_location
    
    @staticmethod
    def update_location(db: Session, location_id: int, location_update: LocationUpdate) -> Optional[Location]:
        """Update location"""
        db_location = db.query(Location).filter(Location.id == location_id).first()
        if not db_location:
            return None
        
        update_data = location_update.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(db_location, key, value)
        
        db.commit()
        db.refresh(db_location)
        return db_location
    
    @staticmethod
    def delete_location(db: Session, location_id: int) -> bool:
        """Delete location"""
        db_location = db.query(Location).filter(Location.id == location_id).first()
        if not db_location:
            return False
        
        db.delete(db_location)
        db.commit()
        return True
    
    @staticmethod
    def get_nearby_locations(
        db: Session,
        latitude: float,
        longitude: float,
        radius_km: float = 50
    ) -> List[Location]:
        """
        Get nearby locations using simple distance calculation
        For production, use PostGIS for accurate geospatial queries
        """
        # Simple approximation: 1 degree ~ 111 km
        degree_radius = radius_km / 111.0
        
        locations = db.query(Location).filter(
            Location.latitude.isnot(None),
            Location.longitude.isnot(None),
            Location.latitude.between(latitude - degree_radius, latitude + degree_radius),
            Location.longitude.between(longitude - degree_radius, longitude + degree_radius)
        ).all()
        
        return locations
    
    @staticmethod
    def update_location_rating(db: Session, location_id: int):
        """Recalculate and update location rating"""
        avg_rating = db.query(func.avg(Review.rating)).filter(
            Review.location_id == location_id
        ).scalar()
        
        total_reviews = db.query(func.count(Review.id)).filter(
            Review.location_id == location_id
        ).scalar()
        
        location = db.query(Location).filter(Location.id == location_id).first()
        if location:
            location.rating_avg = float(avg_rating) if avg_rating else 0.0
            location.total_reviews = total_reviews or 0
            db.commit()
