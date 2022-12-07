//
//  RegisterProductViewController.swift
//  OpenMarket
//
//  Created by baem, minii on 2022/12/02.
//

// TODO: - 추가적으로 할일
/*
 1. NameSpace 만들기
 2. NetworkError Alert 만들기
 3. 업로드 후 데이터 다시 받아오기
 4. pagenation 구현하기
 */

import UIKit

final class RegisterProductViewController: UIViewController {
    // MARK: - Properties
    private var isEditingMode: Bool = false {
        didSet {
            if isEditingMode {
                navigationItem.title = "상품수정"
            } else {
                navigationItem.title = "상품등록"
            }
            
            collectionView.reloadData()
        }
    }
    private var selectedCurrency = Currency.KRW {
        didSet {
            changeKeyboard()
        }
    }
    
    private var selectedImage = Array<UIImage?>(repeating: nil, count: 5)
    private var selectedIndex: Int = 0
    private let networkManager = NetworkManager<ProductListResponse>()
    
    // MARK: - View Properties
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        return collectionView
    }()
    
    private let productNameTextField = UITextField(placeholder: "상품명")
    private let productPriceTextField = UITextField(placeholder: "상품가격", keyboardType: .numberPad)
    private let discountPriceTextField = UITextField(placeholder: "할인금액", keyboardType: .numberPad)
    private let stockTextField = UITextField(placeholder: "재고수량", keyboardType: .numberPad)
    
    private let currencySegment: UISegmentedControl = {
        let segment = UISegmentedControl(items: Currency.allCases.map(\.rawValue))
        segment.selectedSegmentIndex = 0
        return segment
    }()
    
    private let descriptionTextView = UITextView(text: "설명", textColor: .secondaryLabel, font: .preferredFont(forTextStyle: .body), spellCheckingType: .no)
    
    private let segmentStackView = UIStackView(axis: .horizontal, distribution: .fill, spacing: 8)
    
    private let totalStackView = UIStackView(axis: .vertical, distribution: .equalSpacing, spacing: 8)
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        currencySegment.addTarget(self, action: #selector(changeSegmentValue), for: .valueChanged)
        
        setupDescriptionTextViewAccessoryView()
        setupSubViewInStackViews()
        configureNavigation()
        setUpDelegate()
        setUpConstraints()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        view.endEditing(true)
    }
}

// MARK: - Business Logic
private extension RegisterProductViewController {
    func convertPostParameters() -> PostParameter? {
        let checker = RegisterProductChecker { [weak self] error in
            self?.presentAlertMessage(error: error)
        }
        
        checker.invalidImage(images: selectedImage)
        guard let name = checker.invalidName(textField: productNameTextField),
              let description = checker.invalidDescription(textView: descriptionTextView),
              let price = checker.invalidPrice(textField: productPriceTextField),
              let currency = checker.invalidCurrency(segment: currencySegment),
              let discounted = checker.invalidDiscountedPrice(textField: discountPriceTextField, price: price) else {
            return nil
        }
        let stock = Int(stockTextField.text ?? "0")
        
        return PostParameter(name: name, description: description, price: price, currency: currency, discounted_price: discounted, stock: stock)
    }
}

// MARK: - Objc Method
private extension RegisterProductViewController {
    @objc func didTappedTextViewDoneButton() {
        view.frame.origin.y = .zero
        additionalSafeAreaInsets = .zero
        descriptionTextView.endEditing(true)
    }
    
    @objc func didTappedNavigationDoneButton() {
        guard let params = convertPostParameters() else {
            print("파라미터 에러")
            return
        }
        
        var httpBodies = selectedImage.compactMap { $0?.convertHttpBody() }
        httpBodies.insert(params.convertHttpBody(), at: 0)
        
        let postPoint = OpenMarketAPI.addProduct(sendId: UUID(), bodies: httpBodies)
        
        networkManager.postProduct(endPoint: postPoint) { result in
            switch result {
            case .success(_):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.navigationController?.popViewController(animated: true)
                }
            case .failure(let error):
                // TODO: - Error Alert 띄우기
                print(error)
            }
        }
    }
    
    @objc func changeSegmentValue() {
        switch Currency(rawInt: currencySegment.selectedSegmentIndex) {
        case .none:
            return
        case .some(let currency):
            self.selectedCurrency = currency
        }
        
        view.endEditing(true)
    }
}

// MARK: - Configure UI
private extension RegisterProductViewController {
    func configureNavigation() {
        let rightButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(didTappedNavigationDoneButton)
        )
        
        navigationItem.rightBarButtonItem = rightButton
        let appearance = UINavigationBarAppearance()
        appearance.backgroundColor = .systemBackground
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationItem.title = "상품등록"
    }
    
    func setupSubViewInStackViews() {
        segmentStackView.configureSubViews(subViews: [productPriceTextField, currencySegment])
        totalStackView.configureSubViews(subViews: [productNameTextField, segmentStackView, discountPriceTextField, stockTextField])
    }
    
    func setUpDelegate() {
        [
            stockTextField,
            productNameTextField,
            productPriceTextField,
            discountPriceTextField
        ].forEach {
            $0.delegate = self
        }
        
        descriptionTextView.delegate = self
        setupCollectionViewDelegate()
    }
    
    func setupCollectionViewDelegate() {
        collectionView.delegate = self
        collectionView.dataSource = self
        
        collectionView.register(
            RegisterCollectionImageCell.self,
            forCellWithReuseIdentifier: RegisterCollectionImageCell.identifier
        )
    }
    
    func addTargetSegment() {
        
    }
    
    func addSubViewsOfContent() {
        [
            collectionView,
            totalStackView,
            descriptionTextView,
            totalStackView,
            descriptionTextView
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
    }
    
    func setUpConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        addSubViewsOfContent()
        
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            collectionView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            collectionView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            collectionView.heightAnchor.constraint(equalTo: safeArea.heightAnchor, multiplier: 0.2),
            
            totalStackView.topAnchor.constraint(equalTo: collectionView.bottomAnchor),
            totalStackView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            totalStackView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            
            descriptionTextView.topAnchor.constraint(equalTo: totalStackView.bottomAnchor),
            descriptionTextView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            descriptionTextView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            descriptionTextView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            
            currencySegment.widthAnchor.constraint(equalTo: productPriceTextField.widthAnchor, multiplier: 0.30)
        ])
    }
    
    func changeKeyboard() {
        if selectedCurrency == Currency.KRW {
            productPriceTextField.keyboardType = .numberPad
            discountPriceTextField.keyboardType = .numberPad
        } else {
            productPriceTextField.keyboardType = .decimalPad
            discountPriceTextField.keyboardType = .decimalPad
        }
        
        productPriceTextField.text = nil
        discountPriceTextField.text = nil
    }
    
    func presentAlertMessage(error: RegisterError) {
        let alert = UIAlertController(title: error.rawValue, message: error.description, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        alert.addAction(cancel)
        
        present(alert, animated: true, completion: nil)
    }
    
    func setupDescriptionTextViewAccessoryView() {
        let toolbar = UIToolbar()
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(didTappedTextViewDoneButton))
        
        toolbar.setItems([flexSpace, doneButton], animated: true)
        toolbar.sizeToFit()
        
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        descriptionTextView.inputAccessoryView = toolbar
        descriptionTextView.contentInset = stockTextField.safeAreaInsets
    }
}

// MARK: - UICollectionViewDataSource
extension RegisterProductViewController: UICollectionViewDataSource {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        let images = selectedImage.compactMap { $0 }
        
        if isEditingMode {
            return images.count
        }
        
        if images.count < 5 {
            return images.count + 1
        }
        
        return images.count
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RegisterCollectionImageCell.identifier,
            for: indexPath
        ) as? RegisterCollectionImageCell else {
            return UICollectionViewCell()
        }
        
        let filteredImage = selectedImage.compactMap { $0 }
        
        if indexPath.item == filteredImage.count {
            cell.configureButtonStyle()
        } else {
            cell.itemImageView.image = filteredImage[indexPath.item]
        }
        
        return cell
    }
}

// MARK: - UICollectinViewDelegateFlowLayout
extension RegisterProductViewController: UICollectionViewDelegateFlowLayout { }

// MARK: - UICollectionViewDelegate
extension RegisterProductViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let viewSize = view.frame.size
        let contentWidth = viewSize.width / 3 - 10
        
        return CGSize(width: contentWidth, height: contentWidth)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        if isEditingMode {
            return
        }
        
        selectedIndex = indexPath.item
        
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = true
        imagePicker.delegate = self
        
        present(imagePicker, animated: true, completion: nil)
    }
}

// MARK: - UIImagePickerControllerDelegate
extension RegisterProductViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
    ) {
        
        if let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
            // 만약에 이미지 비율이 1이 아니면 -> 이미지의 비율을 1로 변경해주는 cropping을 한다.
            var originImage = image
            var imageScale = 1.0
            var imageSize = originImage.compressionSize
            
            if originImage.size.height != originImage.size.width {
                originImage = originImage.resizeOfSquare()
                imageSize = originImage.compressionSize
            }
            
            while imageSize ?? 0 > 60000 {
                originImage = originImage.downSampling(scale: imageScale)
                imageSize = originImage.compressionSize
                imageScale -= 0.1
            }
            
            selectedImage[selectedIndex] = originImage
        }
        
        collectionView.reloadData()
        picker.dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension RegisterProductViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        view.frame.origin.y = -textField.frame.origin.y
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.frame.origin.y = 0
        textField.endEditing(true)
        return true
    }
}

// MARK: - UITextViewDelegate
extension RegisterProductViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .secondaryLabel {
            textView.text = nil
            textView.textColor = .label
        }
        
        guard let accessoryView = textView.inputAccessoryView else {
            return
        }
        
        additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: accessoryView.frame.height, right: 0)
        
        view.frame.origin.y = -(textView.frame.origin.y - view.safeAreaInsets.top)
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "설명"
            textView.textColor = .secondaryLabel
        }
    }
}
