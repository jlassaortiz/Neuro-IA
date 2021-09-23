% Genero dataset
% Crea varios .txt que tiene como nombre la fecha, número penetración y
% número de id del protocolo. El contenido del archivo es el sliding window
% de la señal neuronal del protocolo para un estímulo en particular.
% Los .txt se generan en el directorio donde esta el archivos de parámetros
% con los directorios de los protocolos.

close all
clear all

% Defino directorio donde esta archivo de parametros con todos los
% directorios de los buenos protocolos de un ave
directorio_params = input('Directorio parametros: ','s');
directorio_params = horzcat(directorio_params , '/');

% Guardo dataset como varios archivos .txt?
guardar_sw = input('\nGuardo sliding window de cada protocolo? (1 = SI / 0 = NO) : ');
ploteo = input('\nPloteo? (1 = SI / 0 = NO) : ');


% Carga vector con directorios para analisis de datos
params_info = dir(horzcat(directorio_params, '*parametros*.txt'));
params = readtable(horzcat(directorio_params,params_info.name),'Delimiter','\t','ReadVariableNames',false);

% Posicion del primer directorio en el archivo de parametros
d = 1;

directorios = params(d:end, :);

% Genero diccionario donde se va a guardar el score de todos
dataset = struct;

% Parámetros de la sliding window (en segundos)
sw_size = 0.015 ;
sw_step = 0.001;

clear d directorio_aux params

% Para cada directorio (protocolo)
for j = (1:1:height(directorios))

    % Defino el directorio del protocolo
    directorio = horzcat(char(directorios.Var2(j)), '/') % directorio protocolo
    
    % Estraigo nombre corto directorio
    directorio_nombre_corto = char(directorios.Var1(j));
    
    % Carga vector con parametros del protocolo
    params_info = dir(horzcat(directorio, '*parametros_protocolo*.txt'));
    params_protocolo = readtable(horzcat(directorio,params_info.name),'Delimiter','\t');
    clear params_info
    
    % Carga vector con parametros del analisis de datos
    params_info = dir(horzcat(directorio, '*parametros_analisis*.txt'));
    params_analisis = readtable(horzcat(directorio,params_info.name),'Delimiter','\t');
    clear params_info

    % Cargo valores de puerto-canal
    puerto = char(params_protocolo.Puerto);
    canal = params_protocolo.Canal;
    puerto_canal = horzcat(puerto, '-0', num2str(canal,'%.2d'))
    clear puerto canal

    % Cargamos cantidad de trials y tiempo que dura cada uno
    ntrials = params_protocolo.Ntrials
    tiempo_file = params_protocolo.tiempo_entre_estimulos
    
    % Especifico numero de id del BOS y REV
    id_BOS = params_analisis.id_bos(1)
    id_REV = params_analisis.id_rev(1)
    
    % Genero songs.mat a partir de las canciones
    estimulos = carga_songs(directorio);
    
    % cargo id_estimulos 
    for i = (1:1:length(estimulos))
        estimulos(i).id = params_analisis.orden(i);
        estimulos(i).frec_corte = params_analisis.freq_corte(i);
        estimulos(i).tipo = categorical(params_analisis.tipo_estimulo(i));
        estimulos(i).protocolo_id = categorical({directorio_nombre_corto});
    end
    clear i 
   
    % Leer info INTAN
    read_Intan_RHD2000_file(horzcat(directorio, 'info.rhd'));
    clear notes spike_triggers supply_voltage_channels aux_input_channels 

    % Levanto el canal de interes
    raw = read_INTAN_channel(directorio, puerto_canal, amplifier_channels);

    % Define el filtro
    filt_spikes = designfilt('highpassiir','DesignMethod','butter','FilterOrder',...
        4,'HalfPowerFrequency',500,'SampleRate',frequency_parameters.amplifier_sample_rate);

    % Aplica filtro
    raw_filtered = filtfilt(filt_spikes, raw);
    clear filt_spikes

    % Genero diccionario con nombre de los estimulos y el momento de presentacion
    estimulos = find_t0s(estimulos, ntrials, tiempo_file, board_adc_channels, frequency_parameters, directorio, false);

    % Definimos umbral de deteccion de spikes
    thr = find_thr(raw_filtered, estimulos, tiempo_file, frequency_parameters);

    % Buscamos spike por threshold cutting
    spike_times = find_spike_times(raw_filtered, thr, frequency_parameters);

    % Genero objeto con raster de todos los estimulos
    estimulos = generate_raster(spike_times, estimulos , tiempo_file, ntrials, frequency_parameters);
    
    % Calculo sw
    [sw_data, sw_tiempo] = sliding_window_fixed_length(estimulos(id_BOS).spikes_norm, ...
        frequency_parameters.amplifier_sample_rate, sw_size, sw_step, ...
        params_protocolo.tiempo_entre_estimulos);

    % Guardo datos en dataset
    dataset(j).protocolo = directorio_nombre_corto;
    dataset(j).sw = sw_data;
    
    % Guardo el sw de este protocolo particular como .txt
    if guardar_sw == 1
        
        writematrix(sw_data, strcat(directorio_params, directorio_nombre_corto, '.txt'));
    end
    
    
    % Grafico
    if ploteo == 1
        
        if j == 1
            maximo = max(sw_data);

            plot(sw_tiempo, sw_data)
            hold on
        else
            plot(sw_tiempo, sw_data + maximo )
            hold on
            
            maximo = maximo + max(sw_data);
        end
    end
    
    
    clear sw_data sw_tiempo
    clear amplifier_channels board_adc_channels frequency_parameters estimulos_aux estimulos estimulos_resumen directorio_nombre_corto
    clear grilla_psth j i id_BOS ntrials params params_analisis pasa_altos pasa_bajos puerto_canal raw raw_filtered spike_times thr tiempo_file directorio

end



clear i j k maximo
