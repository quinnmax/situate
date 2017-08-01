function classifier_struct = oracle_train( ~, ~, ~, additional_parameters_struct )
% classifier_struct = oracle_train( [noise_level_mu], [noise_level_sigma] );

    if ~exist('additional_parameters_struct','var') || isempty(additional_parameters_struct)
        mu = 0;
    else
        mu = additional_parameters_struct.mu;
    end
    
    if ~exist('additional_parameters_struct','var') || isempty(additional_parameters_struct)
        sigma = .035;
    else
        additional_parameters_struct = additional_parameters_struct.sigma;
    end

    classifier_struct = [];
    classifier_struct.mu = mu;
    classifier_struct.sigma = sigma;

end