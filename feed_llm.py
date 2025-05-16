import os


def coletar_codigo(root_dir: str, output_file: str):
    """
    Percorre root_dir buscando arquivos .cs e .dart e concatena
    seus conteúdos em output_file, acrescentando um cabeçalho com o caminho de cada arquivo.
    """
    with open(output_file, 'w', encoding='utf-8') as out:
        for dirpath, dirs, files in os.walk(root_dir):
            dirs[:] = [d for d in dirs if d not in ('.dart_tool', 'obj', 'Migrations')]
            for filename in files:
                if filename.lower().endswith(('.cs', '.dart')):
                    file_path = os.path.join(dirpath, filename)
                    out.write(f"// === Arquivo: {file_path} ===\n")
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            out.write(f.read())
                    except Exception as e:
                        out.write(f"// ERRO AO LER {file_path}: {e}\n")
                    out.write("\n\n")


if __name__ == "__main__":
    root_dir = os.getcwd()
    output_file = 'all_code.txt'
    print(f"[+] Iniciando coleta em: {root_dir}")
    coletar_codigo(root_dir, output_file)
    print(f"[+] Concluído! Tudo salvo em: {output_file}")