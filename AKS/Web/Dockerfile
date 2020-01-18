#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/core/aspnet:3.1-buster-slim AS base
WORKDIR /app
EXPOSE 80

#
# Angular Client build
#
FROM node:12 as angular-build
WORKDIR /app

# Install NPM packages
COPY Web/ClientApp/package*.json /app/
RUN npm set progress=true
RUN npm cache clean --force
RUN npm install

# Copy Angular source code to app folder
COPY Web/ClientApp /app/

# Build Angular application
ARG configuration=prod
RUN npm run build -- --$configuration

FROM mcr.microsoft.com/dotnet/core/sdk:3.1-buster AS build
WORKDIR /src
COPY ["Web/Web.csproj", "Web/"]
RUN dotnet restore "Web/Web.csproj"
COPY . .
WORKDIR "/src/Web"
RUN dotnet build "Web.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Web.csproj" -c Release -o /app/publish
COPY --from=angular-build /app/dist /app/publish/ClientApp/dist/

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Web.dll"]