using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FloralImage.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class _8 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "Email",
                table: "Customers",
                newName: "Contact");

            migrationBuilder.AddColumn<string>(
                name: "AdditionalInfo",
                table: "Customers",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AdditionalInfo",
                table: "Customers");

            migrationBuilder.RenameColumn(
                name: "Contact",
                table: "Customers",
                newName: "Email");
        }
    }
}
