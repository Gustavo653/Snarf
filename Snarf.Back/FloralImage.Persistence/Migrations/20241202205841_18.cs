using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FloralImage.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class _18 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BankSlipBarCode",
                table: "Invoices");

            migrationBuilder.RenameColumn(
                name: "BankSlipDueDate",
                table: "Invoices",
                newName: "BillDueDate");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "BillDueDate",
                table: "Invoices",
                newName: "BankSlipDueDate");

            migrationBuilder.AddColumn<string>(
                name: "BankSlipBarCode",
                table: "Invoices",
                type: "text",
                nullable: true);
        }
    }
}
