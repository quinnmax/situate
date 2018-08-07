
function model = uniform_normal_mix_fit( situation_struct, data_in, varargin )
% model = uniform_normal_mix_fit( situation_struct, data_in, p_uniform_pre_conditioning, p_uniform_post_conditioning );
% model = uniform_normal_mix_fit( situation_struct, data_in, p_uniform_post_conditioning );
% model = uniform_normal_mix_fit( situation_struct, data_in );
%
% p_uniform_pre_conditioning default is 1
% p_uniform_post_conditioning default is .5

    switch length(varargin)
        case 0
            p_uniform_pre_conditioning  = 1;
            p_uniform_post_conditioning = .5;
        case 1
            p_uniform_pre_conditioning  = 1;
            p_uniform_post_conditioning = varargin{1};
        case 2
            p_uniform_pre_conditioning  = varargin{1};
            p_uniform_post_conditioning = varargin{2};
        otherwise
            warning('too many input args');
    end
        
    model = situation_models.normal_fit( situation_struct, data_in );
    model.p_uniform_pre_conditioning  = p_uniform_pre_conditioning;
    model.p_uniform_post_conditioning = p_uniform_post_conditioning;
    model.model_description = 'uniform_normal_mix';
    
end















