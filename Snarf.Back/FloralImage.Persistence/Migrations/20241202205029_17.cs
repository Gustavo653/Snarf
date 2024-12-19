using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FloralImage.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class _17 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Adiciona uma coluna temporária para armazenar o valor convertido
            migrationBuilder.AddColumn<DateTime>(
                name: "BillDueDate_Temp",
                table: "Customers",
                type: "timestamp without time zone",
                nullable: true);

            // Converte os dados existentes de inteiro para timestamp (ajustar conforme necessário)
            migrationBuilder.Sql(@"
                UPDATE ""Customers""
                SET ""BillDueDate_Temp"" = TO_TIMESTAMP(
                    CONCAT(
                        EXTRACT(YEAR FROM NOW()), '-', 
                        EXTRACT(MONTH FROM NOW()), '-', 
                        ""BillDueDate""
                    ),
                    'YYYY-MM-DD'
                )
                WHERE ""BillDueDate"" IS NOT NULL;
            ");

            // Remove a coluna original
            migrationBuilder.DropColumn(
                name: "BillDueDate",
                table: "Customers");

            // Renomeia a coluna temporária para o nome original
            migrationBuilder.RenameColumn(
                name: "BillDueDate_Temp",
                table: "Customers",
                newName: "BillDueDate");

            // Define a nova coluna como NOT NULL
            migrationBuilder.AlterColumn<DateTime>(
                name: "BillDueDate",
                table: "Customers",
                type: "timestamp without time zone",
                nullable: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Adicionar uma coluna temporária para armazenar os valores convertidos de volta para inteiro
            migrationBuilder.AddColumn<int>(
                name: "BillDueDate_Temp",
                table: "Customers",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            // Converter os valores de DateTime para um formato inteiro
            // Exemplo: Convertendo o timestamp para um formato específico (YYYYMMDD como número)
            migrationBuilder.Sql(@"
                UPDATE ""Customers""
                SET ""BillDueDate_Temp"" = EXTRACT(DAY FROM ""BillDueDate"")::integer");

            // Remover a coluna atual "BillDueDate"
            migrationBuilder.DropColumn(
                name: "BillDueDate",
                table: "Customers");

            // Renomear a coluna temporária de volta para "BillDueDate"
            migrationBuilder.RenameColumn(
                name: "BillDueDate_Temp",
                table: "Customers",
                newName: "BillDueDate");
        }

    }
}
