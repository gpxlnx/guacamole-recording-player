#!/usr/bin/env python3
"""
Servidor HTTP simples para listar arquivos de gravação.
Retorna JSON com lista de arquivos disponíveis.
"""

import os
import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading

# Extensões de arquivo de gravação Guacamole
RECORDING_EXTENSIONS = ['.guac', '.cast']

# Diretório padrão de gravações
DEFAULT_RECORDINGS_DIR = '/gravacoes'

def is_likely_recording_file(filepath):
    """
    Verifica se um arquivo é provavelmente uma gravação Guacamole.
    Para arquivos sem extensão, verifica magic bytes ou assume que é gravação.
    """
    # Verificar extensão primeiro
    _, ext = os.path.splitext(filepath)
    if ext.lower() in RECORDING_EXTENSIONS:
        return True
    
    # Se não tem extensão, verificar se é arquivo e tem tamanho razoável
    try:
        stat = os.stat(filepath)
        # Arquivos muito pequenos provavelmente não são gravações
        if stat.st_size < 50:
            return False
        
        # Para arquivos sem extensão (como UUIDs), assumir que são gravações
        # se tiverem tamanho razoável
        # Gravações Guacamole são arquivos de texto com instruções
        return True
    except:
        return False

def list_recordings(directory):
    """
    Lista arquivos de gravação em um diretório.
    
    Args:
        directory: Caminho do diretório a listar
        
    Returns:
        Lista de dicionários com informações dos arquivos
    """
    recordings = []
    
    if not os.path.exists(directory):
        return recordings
    
    if not os.path.isdir(directory):
        return recordings
    
    try:
        for item in os.listdir(directory):
            item_path = os.path.join(directory, item)
            
            # Ignorar arquivos ocultos
            if item.startswith('.'):
                continue
            
            # Verificar se é arquivo de gravação
            if os.path.isfile(item_path):
                # Verificar se é provavelmente uma gravação
                if is_likely_recording_file(item_path):
                    stat = os.stat(item_path)
                    # Caminho relativo ao diretório base de gravações
                    # Se directory é /gravacoes/bi e base é /gravacoes, path deve ser /bi/nome_arquivo
                    base_dir = os.environ.get('RECORDINGS_BASE_DIR', DEFAULT_RECORDINGS_DIR)
                    if directory.startswith(base_dir):
                        # Caminho relativo ao base_dir
                        rel_path = os.path.relpath(item_path, base_dir)
                    else:
                        # Se não está dentro do base_dir, usar relativo ao directory
                        rel_path = os.path.relpath(item_path, directory)
                    
                    # Garantir que começa com /
                    if not rel_path.startswith('/'):
                        rel_path = '/' + rel_path.replace('\\', '/')
                    
                    recordings.append({
                        'name': item,
                        'path': rel_path,
                        'size': stat.st_size,
                        'modified': stat.st_mtime
                    })
            # Se for diretório, listar recursivamente
            elif os.path.isdir(item_path):
                sub_recordings = list_recordings(item_path)
                # Adicionar prefixo do diretório aos nomes
                for rec in sub_recordings:
                    rec['name'] = os.path.join(item, rec['name'])
                    rec['path'] = '/' + os.path.join(item, rec['path'].lstrip('/'))
                recordings.extend(sub_recordings)
    
    except PermissionError:
        pass
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
    
    # Ordenar por nome
    recordings.sort(key=lambda x: x['name'])
    
    return recordings

class ListFilesHandler(BaseHTTPRequestHandler):
    """Handler HTTP para listar arquivos."""
    
    def do_GET(self):
        """Processa requisições GET."""
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/api/list-files' or parsed_path.path == '/list-files':
            # Obter diretório dos parâmetros ou usar o diretório configurado
            query_params = parse_qs(parsed_path.query)
            requested_dir = query_params.get('dir', [None])[0]
            
            # Usar diretório da requisição ou o diretório padrão do servidor
            if requested_dir:
                directory = requested_dir
            else:
                # Usar o diretório configurado no servidor (via argumento --dir)
                directory = os.environ.get('RECORDINGS_DIR', DEFAULT_RECORDINGS_DIR)
            
            # Normalizar caminho
            directory = os.path.normpath(directory)
            
            # Verificar se diretório existe
            if not os.path.exists(directory):
                self.send_response(404)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                response = {'error': f'Directory not found: {directory}', 'recordings': []}
                self.wfile.write(json.dumps(response).encode())
                return
            
            # Definir diretório base para cálculo de paths relativos
            base_dir = os.environ.get('RECORDINGS_BASE_DIR', DEFAULT_RECORDINGS_DIR)
            if not base_dir:
                base_dir = DEFAULT_RECORDINGS_DIR
            
            # Listar arquivos
            recordings = list_recordings(directory)
            
            # Retornar JSON
            result = {
                'directory': directory,
                'recordings': recordings,
                'count': len(recordings)
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(result).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suprime logs padrão."""
        pass

def run_server(port=8888, recordings_dir=DEFAULT_RECORDINGS_DIR):
    """Executa o servidor HTTP."""
    global DEFAULT_RECORDINGS_DIR
    DEFAULT_RECORDINGS_DIR = recordings_dir
    
    server_address = ('127.0.0.1', port)
    httpd = HTTPServer(server_address, ListFilesHandler)
    
    print(f"Server running on http://127.0.0.1:{port}")
    print(f"Recordings directory: {recordings_dir}")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        httpd.shutdown()

def main():
    """Função principal."""
    import argparse
    
    parser = argparse.ArgumentParser(description='List Guacamole recording files')
    parser.add_argument('--port', type=int, default=8888, help='Port to listen on (default: 8888)')
    parser.add_argument('--dir', type=str, default=DEFAULT_RECORDINGS_DIR, help='Recordings directory')
    
    args = parser.parse_args()
    
    run_server(args.port, args.dir)

if __name__ == '__main__':
    main()

