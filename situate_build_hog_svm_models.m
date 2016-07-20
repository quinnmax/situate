function returned_models = situate_build_hog_svm_models( fnames_lb_train, p )

    features_pos = cell(1,length(p.situation_objects));
    features_neg = cell(1,length(p.situation_objects));
    
    for fi = 1:length(fnames_lb_train)
        
        cur_fname_lb = fnames_lb_train{fi};
        
        for oi = 1:length(p.situation_objects)
            cur_object_label = p.situation_objects{oi};
            num_negatives = 3;
            [crops_pos_cell, crops_neg_cell] = situate_crop_extractor( cur_fname_lb, cur_object_label, p, num_negatives );

            temp_pos = cellfun( @(x) extractHOGFeatures(imresize(x,[100 100])), crops_pos_cell, 'UniformOutput', false );
            temp_neg = cellfun( @(x) extractHOGFeatures(imresize(x,[100 100])), crops_neg_cell, 'UniformOutput', false );

            features_pos{oi} = [features_pos{oi}; cell2mat(temp_pos')];
            features_neg{oi} = [features_neg{oi}; cell2mat(temp_neg')];

        end
        
    end
    
    % build 1vAll classifiers
    
    models = cell(1,length(p.situation_objects));
    for oi = 1:length(p.situation_objects)
        data = [features_pos{oi}; features_neg{oi}];
        labels = [true(size(features_pos{oi},1),1); false(size(features_neg{oi},1),1)];
        temp_model = fitcsvm(data,labels);
        models{oi} = fitSVMPosterior(temp_model);
    end
    
    returned_models = models;
    returned_models.objects_in_indexing_order = p.situation_objects;
    
end








