
function experiment_run( experiment_file_fname )



    % situate.experiment_run( experiment_file_fname.json )

    if ~exist('experiment_file_fname','var') || isempty(experiment_file_fname)

        experiment_file_fname = 'parameters_experiment_dogwalking_check.json';
        % experiment_file_fname = 'parameters_experiment_dogwalking_viz.json';

    end



%% load params from files

    experiment_struct = jsondecode_file( experiment_file_fname );

    situation_struct = situate.situation_struct_load_json( experiment_struct.situation_definition_fname );

    situate_running_params_array = [];
    for pi = length( experiment_struct.situate_parameterizations_fnames ):-1:1
        cur_params = situate.parameters_initialize_from_file( experiment_struct.situate_parameterizations_fnames{pi} );
        if isempty( situate_running_params_array ), situate_running_params_array = cur_params; end
        situate_running_params_array(pi) = cur_params; 
    end



%% Make results directory

    experiment_struct.results_directory = fullfile('results',[experiment_struct.experiment_settings.description '_' datestr(now,'yyyy.mm.dd.HH.MM.SS')]);                                                                                          
    if ~exist(experiment_struct.results_directory,'dir') ...
    && ~experiment_struct.experiment_settings.use_visualizer
        mkdir(experiment_struct.results_directory); 
        display(['made results directory ' experiment_struct.results_directory]); 
    end

    
    
%% add copies of experiment def, situation def, and parameters def to the results folder
    
    if ~experiment_struct.experiment_settings.use_visualizer

        % experiment def
        [~,name,ext] = fileparts( experiment_file_fname );
        copyfile( experiment_file_fname, fullfile( experiment_struct.results_directory, [name ext]) );

        % situation def
        [~,name,ext] = fileparts( experiment_struct.situation_definition_fname );
        copyfile( experiment_struct.situation_definition_fname, fullfile( experiment_struct.results_directory, [name ext]) );

        % params defs
        for i = 1:length( experiment_struct.situate_parameterizations_fnames )
            [~,name,ext] = fileparts( experiment_struct.situate_parameterizations_fnames{i} );
            copyfile( experiment_struct.situate_parameterizations_fnames{i}, ...
                      fullfile( experiment_struct.results_directory, [name ext] ) );
        end

    end

    

%% Run the experiment 

    if  experiment_struct.experiment_settings.use_parallel ...
    && ~experiment_struct.experiment_settings.use_visualizer 
        situate.experiment_handler_parallel( experiment_struct, situation_struct, situate_running_params_array );
    else        
        situate.experiment_handler( experiment_struct, situation_struct, situate_running_params_array );        
    end
    
    

%% Run the analysis 

    if experiment_struct.experiment_settings.run_analysis_after_completion ...
    && ~experiment_struct.experiment_settings.use_visualizer
        % situate_experiment_analysis( experiment_struct.results_directory );
        analysis.main( experiment_struct.results_directory );
    end
    
    
    
end

















