
function model = uniform_normal_mix_fit( situation_struct, data_in, uniform_after_conditioning_probability )
% model = uniform_normal_mix_fit( situation_struct, data_in, uniform_after_conditioning_probability );

    if ~exist('uniform_after_conditioning_probability','var') || isempty(uniform_after_conditioning_probability) 
        uniform_after_conditioning_probability = .5;
    end

    model = situation_models.normal_fit( situation_struct, data_in );
    model.probability_of_uniform_after_conditioning = uniform_after_conditioning_probability;
    
end















