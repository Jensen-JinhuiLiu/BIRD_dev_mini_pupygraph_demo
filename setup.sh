docker compose up -d
docker compose logs -f postgres
docker exec -i ai-agent-postgres psql -U root -d postgres -c "CREATE DATABASE bird_dev_mini;"

# the sql file can be downloaded here: https://drive.google.com/file/d/1MAS3Ty0mLY9q8bsPCrxdCJH5ywS0pTWk/view?usp=drive_link
docker exec -i ai-agent-postgres psql -U root -d bird_dev_mini < BIRD_dev_postgresql_separated_schemas.sql