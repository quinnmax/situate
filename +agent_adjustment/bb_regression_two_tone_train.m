function model = bb_regression_two_tone_train ( p, fnames_in, saved_models_directory, training_IOU_thresholds )

    model_description = 'box_adjust_two_tone';
    
    fnames_in_pathless = fileparts_mq(fnames_in, 'name' );
    model_fname = situate.check_for_existing_model(...
        {saved_models_directory,'default_models'}, ...
        'fnames_train',fnames_in_pathless,...
        'model_description',model_description, ...
        'IOU_thresholds', training_IOU_thresholds, ...
        'object_types', p.situation_objects);
    
    if ~isempty(model_fname)
        model = load(model_fname);
        display(['box_adjust two tone model loaded from ' model_fname]);
        display(repmat(' ',1,100));
        return;
    end

    model = [];
    model.model_description = model_description;
    model.object_types = p.situation_objects;
    model.fnames_train = fnames_in;
    model.IOU_thresholds = training_IOU_thresholds;
    model.feature_descriptions = {'delta x in widths','delta y in heights','log w ratio','log h ratio'};
    model.sub_models = cell(1,2);
    
    model_a = agent_adjustment.bb_regression_train( p, fnames_in, saved_models_directory, min(training_IOU_thresholds) );
    model_b = agent_adjustment.bb_regression_train( p, fnames_in, saved_models_directory, max(training_IOU_thresholds) );
    
    model.sub_models{1} = model_a;
    model.sub_models{2} = model_b;
    
    % visualize how they do at different estimated IOUs
    visualize_model_quality = false;
    if visualize_model_quality
        figure;
        for oi = 1:length(p.situation_objects)
            subplot(1,length(p.situation_objects),oi)
            plot( model_a.adjustment_results_training{oi}.improvement_bin_centers, ...
                  model_a.adjustment_results_training{oi}.improvement_mean, ...
                  'b' );
            hold on;
            plot( model_a.adjustment_results_training{oi}.improvement_bin_centers, ...
                  model_a.adjustment_results_training{oi}.improvement_mean + 2 * model_a.adjustment_results_training{oi}.improvement_std, ...
                  '--b' );
            plot( model_a.adjustment_results_training{oi}.improvement_bin_centers, ...
                  model_a.adjustment_results_training{oi}.improvement_mean - 2 * model_a.adjustment_results_training{oi}.improvement_std, ...
                  '--b' );
              
            plot( model_b.adjustment_results_training{oi}.improvement_bin_centers, ...
                  model_b.adjustment_results_training{oi}.improvement_mean, ...
                  'r' );
            plot( model_b.adjustment_results_training{oi}.improvement_bin_centers, ...
                  model_b.adjustment_results_training{oi}.improvement_mean + 2 * model_b.adjustment_results_training{oi}.improvement_std, ...
                  '--r' );
          plot( model_b.adjustment_results_training{oi}.improvement_bin_centers, ...
                  model_b.adjustment_results_training{oi}.improvement_mean - 2 * model_b.adjustment_results_training{oi}.improvement_std, ...
                  '--r' );
            plot([0 1],[0 0],'--k');
            legend('model a', 'model b');
            title(p.situation_objects{oi});
        end
    end
    
    % determine the cutoff point for switching from one model to the other. it look slike it's
    % around .5 that the expected gain switches from model a to b for each dogwalking object type,
    % but it also seems to have higher variance at (nearly) all IOUs. that makes me want to go ahead
    % and switch to model b earlier. maybe when mean-2*std is higher, rather than just mean.
    model_selection_threshold = zeros( 1, length(p.situation_objects) );
    for oi = 1:length(p.situation_objects)
        a_mean_minus_std = model_a.adjustment_results_training{oi}.improvement_mean - 2 * model_a.adjustment_results_training{oi}.improvement_std;
        b_mean_minus_std = model_b.adjustment_results_training{oi}.improvement_mean - 2 * model_b.adjustment_results_training{oi}.improvement_std;
        ba_diff = b_mean_minus_std - a_mean_minus_std;
        ba_diff = interp( ba_diff, 3);
        bin_centers = interp( model_a.adjustment_results_training{oi}.improvement_bin_centers, 3 );
        ba_diff(1:round(.2*length(ba_diff))) = 0;
        ba_diff(end-round(.2*length(ba_diff)):end) = 0;
        cutoff_ind = find( gt( ba_diff, 0 ), 1, 'first' );
        cutoff_val = bin_centers(cutoff_ind);
        model_selection_threshold(oi) = cutoff_val;
    end
    
    model.model_selection_threshold = model_selection_threshold;
        
    iter = 0;
    saved_model_fname = fullfile( saved_models_directory, [ [p.situation_objects{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
    while exist(saved_model_fname,'file')
        iter = iter + 1;
        saved_model_fname = fullfile( saved_models_directory, [ [p.situation_objects{:}] ', ' model_description ', ' num2str(iter) '.mat'] );
    end
    save(saved_model_fname,'-struct','model');
    display(['saved ' model_description ' model to: ' saved_model_fname ]);
    
    
end
    
    