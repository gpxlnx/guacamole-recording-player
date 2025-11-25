/*
 * Copyright (C) 2025
 *
 * Directive para listar e selecionar arquivos do servidor.
 */

angular.module('file').directive('guacServerFileList', [function guacServerFileList() {

    var config = {
        restrict : 'E',
        templateUrl : 'modules/file/templates/serverFileList.html',
        scope : {
            file : '=',
            loading : '=',
            error : '=',
            errorMessage : '='
        }
    };

    config.controller = ['$scope', '$interval', 'serverFileService', function guacServerFileListController($scope, $interval, serverFileService) {
        
        $scope.recordings = [];
        $scope.selectedDirectory = null;
        $scope.directories = [];
        $scope.autoRefresh = true;
        $scope.refreshInterval = 30000; // 30 segundos (padrão)
        $scope.refreshTimer = null;
        $scope.lastUpdate = null;
        $scope.recordingsCount = 0;
        
        /**
         * Carrega lista de gravações do servidor.
         */
        $scope.loadRecordings = function loadRecordings(directory, silent) {
            if (!silent) {
                $scope.loading = true;
            }
            $scope.error = false;
            $scope.errorMessage = null;
            
            serverFileService.listRecordings(directory)
                .then(function success(recordings) {
                    var newCount = recordings.length;
                    var hadNewFiles = newCount > $scope.recordingsCount && $scope.recordingsCount > 0;
                    
                    $scope.recordings = recordings;
                    $scope.recordingsCount = newCount;
                    $scope.loading = false;
                    $scope.lastUpdate = new Date();
                    
                    // Se houver novos arquivos e estiver em modo silencioso, mostrar notificação sutil
                    if (hadNewFiles && silent) {
                        // Pode adicionar uma notificação visual aqui se desejar
                        console.log('New recordings detected:', newCount - $scope.recordingsCount);
                    }
                })
                .catch(function error(message) {
                    $scope.error = true;
                    $scope.errorMessage = message;
                    $scope.loading = false;
                    $scope.recordings = [];
                });
        };
        
        /**
         * Inicia atualização automática.
         */
        $scope.startAutoRefresh = function startAutoRefresh() {
            if ($scope.refreshTimer) {
                $interval.cancel($scope.refreshTimer);
            }
            
            if ($scope.autoRefresh) {
                $scope.refreshTimer = $interval(function() {
                    $scope.loadRecordings($scope.selectedDirectory, true);
                }, $scope.refreshInterval);
            }
        };
        
        /**
         * Para atualização automática.
         */
        $scope.stopAutoRefresh = function stopAutoRefresh() {
            if ($scope.refreshTimer) {
                $interval.cancel($scope.refreshTimer);
                $scope.refreshTimer = null;
            }
        };
        
        /**
         * Alterna atualização automática.
         */
        $scope.toggleAutoRefresh = function toggleAutoRefresh() {
            $scope.autoRefresh = !$scope.autoRefresh;
            if ($scope.autoRefresh) {
                $scope.startAutoRefresh();
            } else {
                $scope.stopAutoRefresh();
            }
        };
        
        /**
         * Atualização manual.
         */
        $scope.refreshNow = function refreshNow() {
            $scope.loadRecordings($scope.selectedDirectory, false);
        };
        
        /**
         * Seleciona um arquivo do servidor.
         */
        $scope.selectFile = function selectFile(recording) {
            $scope.loading = true;
            $scope.error = false;
            $scope.errorMessage = null;
            
            // Construir caminho relativo
            var filePath = recording.path;
            // O path já vem relativo do servidor, apenas garantir que começa com /
            if (!filePath.startsWith('/')) {
                filePath = '/' + filePath;
            }
            
            serverFileService.loadFile(filePath)
                .then(function success(blob) {
                    $scope.file = blob;
                    $scope.loading = false;
                })
                .catch(function error(message) {
                    $scope.error = true;
                    $scope.errorMessage = message;
                    $scope.loading = false;
                });
        };
        
        /**
         * Formata tamanho do arquivo.
         */
        $scope.formatFileSize = function formatFileSize(bytes) {
            if (!bytes) return '0 B';
            var k = 1024;
            var sizes = ['B', 'KB', 'MB', 'GB'];
            var i = Math.floor(Math.log(bytes) / Math.log(k));
            return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
        };
        
        /**
         * Formata data de modificação.
         */
        $scope.formatDate = function formatDate(timestamp) {
            if (!timestamp) return '';
            var date = new Date(timestamp * 1000);
            return date.toLocaleString();
        };
        
        // Carregar gravações ao inicializar
        $scope.loadRecordings();
        
        // Iniciar atualização automática
        $scope.startAutoRefresh();
        
        // Limpar intervalo ao destruir o escopo
        $scope.$on('$destroy', function() {
            $scope.stopAutoRefresh();
        });
    }];

    return config;

}]);

