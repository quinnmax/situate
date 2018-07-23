
function model = uniform_normal_mix_fit( situation_struct, data_in, p_uniform_post_conditioning )
% model = uniform_normal_mix_fit( situation_struct, data_in, uniform_after_conditioning_probability );

    if ~exist('uniform_after_conditioning_probability','var') || isempty(p_uniform_post_conditioning) 
        p_uniform_post_conditioning = .5;
    end

    model = situation_models.normal_fit( situation_struct, data_in );
    model.p_uniform_pre_conditioning = 1;
    model.p_uniform_post_conditioning = p_uniform_post_conditioning;
    model.model_description = 'uniform_normal_mix';
    
end















