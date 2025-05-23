# <img src="recommendsymptom/assets/screen/Screen1.png" width="30%" height="50%"> <img src="recommendsymptom/assets/screen/Screen2.png" width="30%" height="50%">

# RecommendSymptom

RecommendSymptom is a mobile-application symptom recommender via similarity based on the patient information and selected symptom by using Case-Based Reasoning and Content-Based Filtering. This application belongs to the second task of Agnos assignment.

## Requirement before starting RecommendSymptom

| Name | Required version(s) |
|------|---------------------|
| Flutter SDK | 3.3.3 or Higher |
| Flutter Doctor | All requirements must be checked |

### Getting Start

1. Clone the respository to your machine.

    ```
   git clone https://github.com/NoppharutKDS/RecommendSymptom.git
    ```
2. Change directory to the local repository by typing this command.

    ```
   cd RecommendSymptom/recommendsymptom
    ```
3. Install all require dependencies.

    ```
   flutter pub get
    ```
4. Choose platform you want to run.
    ```
   - iOS
   - Android
    ```
5. Running the application by this command.
    ```
   flutter run
    ```

### Data Flow Explained
Symptom Selection Widget ─> State Management (setState / Provider) ─> Recommender Function ─> Recommended Results Display Widget
