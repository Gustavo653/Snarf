using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Snarf.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class _22 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_BlockedUsers_AspNetUsers_BlockedId",
                table: "BlockedUsers");

            migrationBuilder.DropForeignKey(
                name: "FK_BlockedUsers_AspNetUsers_BlockerId",
                table: "BlockedUsers");

            migrationBuilder.DropForeignKey(
                name: "FK_FavoriteChats_AspNetUsers_ChatUserId",
                table: "FavoriteChats");

            migrationBuilder.DropForeignKey(
                name: "FK_FavoriteChats_AspNetUsers_UserId",
                table: "FavoriteChats");

            migrationBuilder.DropForeignKey(
                name: "FK_Parties_AspNetUsers_OwnerId",
                table: "Parties");

            migrationBuilder.DropColumn(
                name: "ExtraVideoCallMinutes",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ImageUrl",
                table: "AspNetUsers");

            migrationBuilder.AddColumn<int[]>(
                name: "Actions",
                table: "AspNetUsers",
                type: "integer[]",
                nullable: false,
                defaultValue: new int[0]);

            migrationBuilder.AddColumn<int>(
                name: "Age",
                table: "AspNetUsers",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Attitude",
                table: "AspNetUsers",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "BirthLatitude",
                table: "AspNetUsers",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "BirthLongitude",
                table: "AspNetUsers",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "BodyType",
                table: "AspNetUsers",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int[]>(
                name: "Carrying",
                table: "AspNetUsers",
                type: "integer[]",
                nullable: false,
                defaultValue: new int[0]);

            migrationBuilder.AddColumn<string>(
                name: "Description",
                table: "AspNetUsers",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int[]>(
                name: "DrugAbuse",
                table: "AspNetUsers",
                type: "integer[]",
                nullable: false,
                defaultValue: new int[0]);

            migrationBuilder.AddColumn<int[]>(
                name: "Expressions",
                table: "AspNetUsers",
                type: "integer[]",
                nullable: false,
                defaultValue: new int[0]);

            migrationBuilder.AddColumn<int[]>(
                name: "Fetishes",
                table: "AspNetUsers",
                type: "integer[]",
                nullable: false,
                defaultValue: new int[0]);

            migrationBuilder.AddColumn<decimal>(
                name: "HeightInCm",
                table: "AspNetUsers",
                type: "numeric",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "HivStatus",
                table: "AspNetUsers",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "HivTestedDate",
                table: "AspNetUsers",
                type: "timestamp without time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "HostingStatus",
                table: "AspNetUsers",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int[]>(
                name: "Immunizations",
                table: "AspNetUsers",
                type: "integer[]",
                nullable: false,
                defaultValue: new int[0]);

            migrationBuilder.AddColumn<int[]>(
                name: "Interactions",
                table: "AspNetUsers",
                type: "integer[]",
                nullable: false,
                defaultValue: new int[0]);

            migrationBuilder.AddColumn<bool>(
                name: "IsCircumcised",
                table: "AspNetUsers",
                type: "boolean",
                nullable: true);

            migrationBuilder.AddColumn<int[]>(
                name: "Kinks",
                table: "AspNetUsers",
                type: "integer[]",
                nullable: false,
                defaultValue: new int[0]);

            migrationBuilder.AddColumn<int>(
                name: "LocationAvailability",
                table: "AspNetUsers",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int[]>(
                name: "LookingFor",
                table: "AspNetUsers",
                type: "integer[]",
                nullable: false,
                defaultValue: new int[0]);

            migrationBuilder.AddColumn<int>(
                name: "Practice",
                table: "AspNetUsers",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "PublicPlace",
                table: "AspNetUsers",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "ShowActions",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowAge",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowAttitude",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowBodyType",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowCarrying",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowDrugAbuse",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowExpressions",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowFetishes",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowHeightInCm",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowHivStatus",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowHivTestedDate",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowHostingStatus",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowImmunizations",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowInteractions",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowIsCircumcised",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowKinks",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowLookingFor",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowPractice",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowPublicPlace",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowSizeInCm",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowSpectrum",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowStiTestedDate",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "ShowWeightInKg",
                table: "AspNetUsers",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<decimal>(
                name: "SizeInCm",
                table: "AspNetUsers",
                type: "numeric",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Spectrum",
                table: "AspNetUsers",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "StiTestedDate",
                table: "AspNetUsers",
                type: "timestamp without time zone",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "WeightInKg",
                table: "AspNetUsers",
                type: "numeric",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "UserPhotos",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Url = table.Column<string>(type: "text", nullable: false),
                    Order = table.Column<int>(type: "integer", nullable: false),
                    UserId = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp without time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp without time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserPhotos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserPhotos_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "VideoCallPurchases",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<string>(type: "text", nullable: false),
                    Minutes = table.Column<int>(type: "integer", nullable: false),
                    PurchaseDate = table.Column<DateTime>(type: "timestamp without time zone", nullable: false),
                    SubscriptionId = table.Column<string>(type: "text", nullable: true),
                    Token = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp without time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp without time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VideoCallPurchases", x => x.Id);
                    table.ForeignKey(
                        name: "FK_VideoCallPurchases_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_UserPhotos_UserId_Order",
                table: "UserPhotos",
                columns: new[] { "UserId", "Order" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_VideoCallPurchases_UserId",
                table: "VideoCallPurchases",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_BlockedUsers_AspNetUsers_BlockedId",
                table: "BlockedUsers",
                column: "BlockedId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_BlockedUsers_AspNetUsers_BlockerId",
                table: "BlockedUsers",
                column: "BlockerId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_FavoriteChats_AspNetUsers_ChatUserId",
                table: "FavoriteChats",
                column: "ChatUserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_FavoriteChats_AspNetUsers_UserId",
                table: "FavoriteChats",
                column: "UserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Parties_AspNetUsers_OwnerId",
                table: "Parties",
                column: "OwnerId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_BlockedUsers_AspNetUsers_BlockedId",
                table: "BlockedUsers");

            migrationBuilder.DropForeignKey(
                name: "FK_BlockedUsers_AspNetUsers_BlockerId",
                table: "BlockedUsers");

            migrationBuilder.DropForeignKey(
                name: "FK_FavoriteChats_AspNetUsers_ChatUserId",
                table: "FavoriteChats");

            migrationBuilder.DropForeignKey(
                name: "FK_FavoriteChats_AspNetUsers_UserId",
                table: "FavoriteChats");

            migrationBuilder.DropForeignKey(
                name: "FK_Parties_AspNetUsers_OwnerId",
                table: "Parties");

            migrationBuilder.DropTable(
                name: "UserPhotos");

            migrationBuilder.DropTable(
                name: "VideoCallPurchases");

            migrationBuilder.DropColumn(
                name: "Actions",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Age",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Attitude",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "BirthLatitude",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "BirthLongitude",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "BodyType",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Carrying",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Description",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "DrugAbuse",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Expressions",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Fetishes",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "HeightInCm",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "HivStatus",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "HivTestedDate",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "HostingStatus",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Immunizations",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Interactions",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "IsCircumcised",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Kinks",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "LocationAvailability",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "LookingFor",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Practice",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "PublicPlace",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowActions",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowAge",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowAttitude",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowBodyType",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowCarrying",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowDrugAbuse",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowExpressions",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowFetishes",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowHeightInCm",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowHivStatus",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowHivTestedDate",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowHostingStatus",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowImmunizations",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowInteractions",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowIsCircumcised",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowKinks",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowLookingFor",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowPractice",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowPublicPlace",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowSizeInCm",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowSpectrum",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowStiTestedDate",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ShowWeightInKg",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "SizeInCm",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Spectrum",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "StiTestedDate",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "WeightInKg",
                table: "AspNetUsers");

            migrationBuilder.AddColumn<int>(
                name: "ExtraVideoCallMinutes",
                table: "AspNetUsers",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "ImageUrl",
                table: "AspNetUsers",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddForeignKey(
                name: "FK_BlockedUsers_AspNetUsers_BlockedId",
                table: "BlockedUsers",
                column: "BlockedId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_BlockedUsers_AspNetUsers_BlockerId",
                table: "BlockedUsers",
                column: "BlockerId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_FavoriteChats_AspNetUsers_ChatUserId",
                table: "FavoriteChats",
                column: "ChatUserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_FavoriteChats_AspNetUsers_UserId",
                table: "FavoriteChats",
                column: "UserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Parties_AspNetUsers_OwnerId",
                table: "Parties",
                column: "OwnerId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
