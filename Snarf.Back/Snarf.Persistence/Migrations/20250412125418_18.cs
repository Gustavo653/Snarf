using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Snarf.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class _18 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "PartyId",
                table: "PartyChatMessages",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.CreateIndex(
                name: "IX_PartyChatMessages_PartyId",
                table: "PartyChatMessages",
                column: "PartyId");

            migrationBuilder.AddForeignKey(
                name: "FK_PartyChatMessages_Parties_PartyId",
                table: "PartyChatMessages",
                column: "PartyId",
                principalTable: "Parties",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PartyChatMessages_Parties_PartyId",
                table: "PartyChatMessages");

            migrationBuilder.DropIndex(
                name: "IX_PartyChatMessages_PartyId",
                table: "PartyChatMessages");

            migrationBuilder.DropColumn(
                name: "PartyId",
                table: "PartyChatMessages");
        }
    }
}
