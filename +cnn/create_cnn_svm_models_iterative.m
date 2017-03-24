function models = create_cnn_svm_models_iterative( training_images, p )
% models = create_cnn_svm_models_iterative( training_images, p );

    num_negs_per_image = 3;
    
    for oi = 1:numel(p.situation_objects)
        
        disp(['Creating CNN-SVM model for ' p.situation_objects{oi}]);

        data   = nan((num_negs_per_image+1)*length(training_images),4096);
        labels = cell((num_negs_per_image+1)*length(training_images),1);
        cur_row = 1;
        
        for imi = 1:length(training_images)
        
            [positives, negatives] = situate.crop_extractor(training_images{imi}, p, p.situation_objects{oi}, num_negs_per_image);
            
            if ~isempty(positives)
                positive_features = cnn_features( positives );
                data(cur_row:cur_row+length(positives)-1,:) = positive_features;
                labels(cur_row:cur_row+length(positives)-1) = repmat({'pos'},length(positives),1);
                cur_row = cur_row + length(positives);
            end
            
            if ~isempty(negatives)
                negative_features = cnn_features( negatives );
                data(cur_row:cur_row+length(negatives)-1,:) = negative_features;
                labels(cur_row:cur_row+length(negatives)-1) = repmat({'neg'},length(negatives),1);
                cur_row = cur_row + length(negatives);
            end
            
            progress(imi,length(training_images),'extracting CNN features from images');
            
        end
        
        remove_inds = cellfun(@isempty,labels);
        data(remove_inds,:) = [];
        labels(remove_inds) = [];
            
        svm_model = fitcsvm(data, labels, 'Standardize', 'on');
        svm_model = fitSVMPosterior(svm_model);
        models{oi, 1} = svm_model.compact;
        
    end
    
end

function data = cnn_features( images )
    data = cell2mat(map(images, @(x) cnn.cnn_process(x)))';
end
