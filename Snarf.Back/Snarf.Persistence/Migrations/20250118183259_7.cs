using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Snarf.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class _7 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PublicChatMessages_AspNetUsers_SenderId",
                table: "PublicChatMessages");

            migrationBuilder.AlterColumn<string>(
                name: "SenderId",
                table: "PublicChatMessages",
                type: "text",
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "text",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_PublicChatMessages_AspNetUsers_SenderId",
                table: "PublicChatMessages",
                column: "SenderId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PublicChatMessages_AspNetUsers_SenderId",
                table: "PublicChatMessages");

            migrationBuilder.AlterColumn<string>(
                name: "SenderId",
                table: "PublicChatMessages",
                type: "text",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "text");

            migrationBuilder.AddForeignKey(
                name: "FK_PublicChatMessages_AspNetUsers_SenderId",
                table: "PublicChatMessages",
                column: "SenderId",
                principalTable: "AspNetUsers",
                principalColumn: "Id");
        }
    }
}
