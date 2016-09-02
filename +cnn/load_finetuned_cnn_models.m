function finetuned_cnn_models = load_finetuned_cnn_models(p)

    run matconvnet/matlab/vl_setupnn

    finetuned_cnn_models = cell(1, numel(p.situation_objects));
    for type = 1:numel(p.situation_objects)
        finetuned_cnn_models{type} = load(['default_models/trained_cnn_' p.situation_objects{type} '.mat']);
        finetuned_cnn_models{type} = finetuned_cnn_models{type}.net;
        finetuned_cnn_models{type}.layers{end}.type = 'softmax';
    end
end

