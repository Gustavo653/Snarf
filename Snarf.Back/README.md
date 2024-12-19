# Introdução 
FloralImage.Back

# Como executar o projeto?
docker run -d --name postgresql --restart always -e POSTGRES_PASSWORD=sua_senha -v /var/lib/postgresql/data:/var/lib/postgresql/data -p 5432:5432 postgres:latest
docker pull gustavo1rx7/FloralImage.Back
docker run -e DatabaseConnection="Host=localhost;Port=5432;Username=postgres;Password=sua_senha;Database=db-FloralImage-prod;Pooling=true;" --restart always -d --name FloralImage-back -p 3000:8080 gustavo1rx7/FloralImage.Back:latest

# Como criar uma migration?
dotnet ef migrations add Initial -p FloralImage.Persistence -s FloralImage.API -c FloralImageContext --verbose
