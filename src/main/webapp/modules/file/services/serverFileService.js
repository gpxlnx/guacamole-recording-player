/*
 * Copyright (C) 2025
 *
 * Service para acessar arquivos do servidor.
 */

angular.module('file').service('serverFileService', ['$http', '$q', function serverFileService($http, $q) {

    /**
     * Lista arquivos de gravação disponíveis no servidor.
     * 
     * @param {String} directory - Diretório a listar (opcional)
     * @returns {Promise} Promise que resolve com lista de arquivos
     */
    this.listRecordings = function listRecordings(directory) {
        var deferred = $q.defer();
        
        var url = '/api/list-files';
        if (directory) {
            url += '?dir=' + encodeURIComponent(directory);
        }
        
        $http.get(url)
            .then(function success(response) {
                if (response.data && response.data.recordings) {
                    deferred.resolve(response.data.recordings);
                } else {
                    deferred.resolve([]);
                }
            })
            .catch(function error(response) {
                var errorMsg = 'Failed to list server recordings';
                if (response.data && response.data.error) {
                    errorMsg = response.data.error;
                } else if (response.status === 404) {
                    errorMsg = 'Recordings directory not found';
                } else if (response.status === 403) {
                    errorMsg = 'Permission denied to access recordings directory';
                }
                deferred.reject(errorMsg);
            });
        
        return deferred.promise;
    };
    
    /**
     * Carrega um arquivo do servidor.
     * 
     * @param {String} filePath - Caminho do arquivo no servidor
     * @returns {Promise} Promise que resolve com Blob do arquivo
     */
    this.loadFile = function loadFile(filePath) {
        var deferred = $q.defer();
        
        // Usar o remoteFileService para carregar via URL
        var url = '/recordings' + filePath;
        
        $http.get(url, {
            responseType: 'blob'
        })
            .then(function success(response) {
                // Criar Blob com nome do arquivo
                var fileName = filePath.split('/').pop();
                var blob = new Blob([response.data], { type: 'application/octet-stream' });
                blob.name = fileName;
                deferred.resolve(blob);
            })
            .catch(function error(response) {
                var errorMsg = 'Failed to load file from server';
                if (response.status === 404) {
                    errorMsg = 'File not found: ' + filePath;
                } else if (response.status === 403) {
                    errorMsg = 'Permission denied to access file';
                }
                deferred.reject(errorMsg);
            });
        
        return deferred.promise;
    };

}]);


