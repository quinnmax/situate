function model = two_tone_train ( p, fnames_in, saved_models_directory, training_IOU_thresholds, model_selection_threshold )

    model_description = 'box_adjust_two_tone';
    %model_selection_threshold = .5;
    
    fnames_in_pathless = cellfun( @(x) x( last(strfind(x,filesep()))+1:end), fnames_in, 'UniformOutput', false );
    model_fname = situate.check_for_existing_model(...
        {saved_models_directory,'default_models'}, ...
        'fnames_train',fnames_in_pathless,...
        'model_description',model_description, ...
        'IOU_thresholds', training_IOU_thresholds, ...
        'model_selection_threshold', model_selection_threshold);
    
    if ~isempty(model_fname)
        model = load(model_fname);
        display(['box_adjust two tone model loaded from ' model_fname]);
        return;
    end

    model = [];
    model.model_description = model_description;
    model.object_types = p.situation_objects;
    model.fnames_train = fnames_in;
    model.IOU_thresholds = training_IOU_thresholds;
    model.model_selection_threshold = model_selection_threshold;
    model.feature_descriptions = {'delta x in widths','delta y in heights','log w ratio','log h ratio'};
    model.sub_models = cell(1,2);
    
    model_a = box_adjust.train( p, fnames_in, saved_models_directory, min(training_IOU_thresholds) );
    model_b = box_adjust.train( p, fnames_in, saved_models_directory, max(training_IOU_thresholds) );
    
    model.sub_models{1} = model_a;
    model.sub_models{2} = model_b;
    
    save_fname = fullfile( saved_models_directory, [model_description '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat']);
    save( save_fname, '-struct', 'model' );
    display(['box_adjust two tone model saved to ' save_fname ]);
    
end
    
    