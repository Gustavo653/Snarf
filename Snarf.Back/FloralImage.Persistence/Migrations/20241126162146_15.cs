using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FloralImage.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class _15 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "BankSlipBarCode",
                table: "Invoices",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "BankSlipDueDate",
                table: "Invoices",
                type: "timestamp without time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BankSlipBarCode",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "BankSlipDueDate",
                table: "Invoices");
        }
    }
}
