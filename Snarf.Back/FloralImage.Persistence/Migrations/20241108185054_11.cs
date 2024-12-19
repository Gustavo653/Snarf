using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FloralImage.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class _11 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AdditionalInfo",
                table: "InvoiceConfigurations");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AdditionalInfo",
                table: "InvoiceConfigurations",
                type: "text",
                nullable: false,
                defaultValue: "");
        }
    }
}
