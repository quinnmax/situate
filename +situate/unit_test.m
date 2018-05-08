

function unit_test( input )
% unit_test( input );
%
% for input from:
%   'pos'
%   'neg'
%   'par'
%   'viz'
%   'train'
%   'all'
%
% or unit_test({'input1','input2'})

    if iscell(input)
        for i = 1:length(input)
            situate.unit_test(input{i});
        end
        return;
    end
    
    params_neg      = 'params_exp/test_script_apply_neg.json';
    params_pos      = 'params_exp/test_script_apply_pos.json';
    params_viz      = 'params_exp/test_script_apply_viz.json';
    params_train    = 'params_exp/test_script_train.json';
    params_parallel = 'params_exp/test_script_parallel.json';

    switch input
        case 'pos'
            situate.experiment_run( params_pos );
        case 'neg'
            situate.experiment_run( params_neg );
        case 'par'
            situate.experiment_run( params_parallel );
        case 'viz'
            situate.experiment_run( params_viz );
        case 'train'
            situate.experiment_run( params_train );
        case 'all'
            situate.experiment_run( params_pos );
            situate.experiment_run( params_neg );
            situate.experiment_run( params_parallel );
            situate.experiment_run( params_train );
            situate.experiment_run( params_viz );
        otherwise
            warning('unrecognized input');
            display(input);
    end
    
end








