using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Snarf.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class _13 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ExtraVideoCallMinutes",
                table: "AspNetUsers",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "VideoCallLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RoomId = table.Column<string>(type: "text", nullable: false),
                    CallerId = table.Column<string>(type: "text", nullable: false),
                    CalleeId = table.Column<string>(type: "text", nullable: false),
                    StartTime = table.Column<DateTime>(type: "timestamp without time zone", nullable: false),
                    EndTime = table.Column<DateTime>(type: "timestamp without time zone", nullable: true),
                    DurationMinutes = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp without time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp without time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VideoCallLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_VideoCallLogs_AspNetUsers_CalleeId",
                        column: x => x.CalleeId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_VideoCallLogs_AspNetUsers_CallerId",
                        column: x => x.CallerId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_VideoCallLogs_CalleeId",
                table: "VideoCallLogs",
                column: "CalleeId");

            migrationBuilder.CreateIndex(
                name: "IX_VideoCallLogs_CallerId",
                table: "VideoCallLogs",
                column: "CallerId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "VideoCallLogs");

            migrationBuilder.DropColumn(
                name: "ExtraVideoCallMinutes",
                table: "AspNetUsers");
        }
    }
}
