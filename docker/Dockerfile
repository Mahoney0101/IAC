FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build-env
WORKDIR /workspace

COPY ./ide ./ide
COPY ./src ./src
RUN dotnet restore ./ide -v m
RUN dotnet publish ./src --output /app/ -c Release --no-restore -v m

FROM mcr.microsoft.com/dotnet/aspnet:5.0
WORKDIR /app
COPY ./certs/Cert.pfx /etc/ssl/certs/Cert.pfx


COPY --from=build-env /app/ .
ENTRYPOINT ["dotnet", "API.dll"]
