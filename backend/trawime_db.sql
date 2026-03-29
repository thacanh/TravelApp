SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE categories (
	id INTEGER NOT NULL AUTO_INCREMENT, 
	slug VARCHAR(50) NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	icon VARCHAR(50), 
	PRIMARY KEY (id)
);

CREATE TABLE locations (
	id INTEGER NOT NULL AUTO_INCREMENT, 
	name VARCHAR(255) NOT NULL, 
	description TEXT, 
	category VARCHAR(50) NOT NULL, 
	address VARCHAR(500), 
	city VARCHAR(100) NOT NULL, 
	country VARCHAR(100), 
	latitude FLOAT, 
	longitude FLOAT, 
	rating_avg FLOAT, 
	total_reviews INTEGER, 
	images JSON, 
	description_embedding JSON, 
	created_by INTEGER, 
	created_at DATETIME, 
	updated_at DATETIME, 
	PRIMARY KEY (id)
);

CREATE TABLE users (
	id INTEGER NOT NULL AUTO_INCREMENT, 
	email VARCHAR(255) NOT NULL, 
	password_hash VARCHAR(255) NOT NULL, 
	full_name VARCHAR(100) NOT NULL, 
	avatar_url VARCHAR(500), 
	phone VARCHAR(20), 
	`role` VARCHAR(20), 
	is_active BOOL, 
	created_at DATETIME, 
	updated_at DATETIME, 
	PRIMARY KEY (id)
);

CREATE TABLE chat_sessions (
	id INTEGER NOT NULL AUTO_INCREMENT, 
	user_id INTEGER NOT NULL, 
	title VARCHAR(255), 
	created_at DATETIME, 
	updated_at DATETIME, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE TABLE favorites (
	id INTEGER NOT NULL AUTO_INCREMENT, 
	user_id INTEGER NOT NULL, 
	location_id INTEGER NOT NULL, 
	created_at DATETIME, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id), 
	FOREIGN KEY(location_id) REFERENCES locations (id)
);

CREATE TABLE itineraries (
	id INTEGER NOT NULL AUTO_INCREMENT, 
	user_id INTEGER NOT NULL, 
	title VARCHAR(255) NOT NULL, 
	description TEXT, 
	start_date DATETIME, 
	end_date DATETIME, 
	status VARCHAR(20), 
	created_at DATETIME, 
	updated_at DATETIME, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE TABLE location_categories (
	location_id INTEGER NOT NULL, 
	category_id INTEGER NOT NULL, 
	PRIMARY KEY (location_id, category_id), 
	FOREIGN KEY(location_id) REFERENCES locations (id) ON DELETE CASCADE, 
	FOREIGN KEY(category_id) REFERENCES categories (id) ON DELETE CASCADE
);

CREATE TABLE reviews (
	id INTEGER NOT NULL AUTO_INCREMENT, 
	user_id INTEGER NOT NULL, 
	location_id INTEGER NOT NULL, 
	rating FLOAT NOT NULL, 
	comment TEXT, 
	photos JSON, 
	visited_at DATETIME, 
	created_at DATETIME, 
	updated_at DATETIME, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id), 
	FOREIGN KEY(location_id) REFERENCES locations (id)
);

CREATE TABLE chat_messages (
	id INTEGER NOT NULL AUTO_INCREMENT, 
	session_id INTEGER NOT NULL, 
	`role` VARCHAR(20) NOT NULL, 
	content TEXT NOT NULL, 
	created_at DATETIME, 
	PRIMARY KEY (id), 
	FOREIGN KEY(session_id) REFERENCES chat_sessions (id)
);

CREATE TABLE itinerary_days (
	id INTEGER NOT NULL AUTO_INCREMENT, 
	itinerary_id INTEGER NOT NULL, 
	day_number INTEGER NOT NULL, 
	date DATE, 
	title VARCHAR(255), 
	description TEXT, 
	created_at DATETIME, 
	PRIMARY KEY (id), 
	FOREIGN KEY(itinerary_id) REFERENCES itineraries (id)
);

CREATE TABLE itinerary_activities (
	id INTEGER NOT NULL AUTO_INCREMENT, 
	day_id INTEGER NOT NULL, 
	location_id INTEGER, 
	title VARCHAR(255) NOT NULL, 
	description TEXT, 
	start_time TIME, 
	end_time TIME, 
	cost_estimate FLOAT, 
	note TEXT, 
	order_index INTEGER, 
	created_at DATETIME, 
	PRIMARY KEY (id), 
	FOREIGN KEY(day_id) REFERENCES itinerary_days (id), 
	FOREIGN KEY(location_id) REFERENCES locations (id)
);

SET FOREIGN_KEY_CHECKS = 1;
