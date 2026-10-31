package models

import "time"

type User struct {
	ID          string    `json:"id"`
	FirebaseUID string    `json:"firebase_uid"`
	Email       string    `json:"email"`
	Name        string    `json:"name"`
	DisplayName string    `json:"display_name"`
	Avatar      string    `json:"avatar"`
	CreatedAt   time.Time `json:"created_at"`
}

type UserProfileInput struct {
	DisplayName string `json:"display_name"`
	Avatar      string `json:"avatar"`
}

type Card struct {
	ID          string    `json:"id"`
	UserID      string    `json:"user_id"`
	Name        string    `json:"name"`
	Franchise   string    `json:"franchise"`
	Color       string    `json:"color"`
	CutOffDay   int       `json:"cut_off_day"`
	PaymentDay  int       `json:"payment_day"`
	CreditLimit *float64  `json:"credit_limit"`
	CreatedAt   time.Time `json:"created_at"`
}

type CardInput struct {
	Name        string   `json:"name"`
	Franchise   string   `json:"franchise"`
	Color       string   `json:"color"`
	CutOffDay   int      `json:"cut_off_day"`
	PaymentDay  int      `json:"payment_day"`
	CreditLimit *float64 `json:"credit_limit"`
}

type Preset struct {
	ID          string    `json:"id"`
	UserID      string    `json:"user_id"`
	Name        string    `json:"name"`
	Icon        string    `json:"icon"`
	Amount      float64   `json:"amount"`
	CategoryID  string    `json:"category_id"`
	CardID      *string   `json:"card_id"`
	Description string    `json:"description"`
	CreatedAt   time.Time `json:"created_at"`
}

type PresetInput struct {
	Name        string  `json:"name"`
	Icon        string  `json:"icon"`
	Amount      float64 `json:"amount"`
	CategoryID  string  `json:"category_id"`
	CardID      *string `json:"card_id"`
	Description string  `json:"description"`
}

type Category struct {
	ID                  string  `json:"id"`
	Name                string  `json:"name"`
	Icon                string  `json:"icon"`
	Color               string  `json:"color"`
	Type                int     `json:"type"`
	RequiresDescription bool    `json:"requires_description"`
	DefaultAmount       float64 `json:"default_amount"`
	UserID              string  `json:"user_id"`
}

type CategoryUpdateInput struct {
	Name                string  `json:"name"`
	Icon                string  `json:"icon"`
	Color               string  `json:"color"`
	Type                int     `json:"type"`
	RequiresDescription bool    `json:"requires_description"`
	DefaultAmount       float64 `json:"default_amount"`
}

type Person struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Name      string    `json:"name"`
	Color     string    `json:"color"`
	Icon      string    `json:"icon"`
	Archived  bool      `json:"archived"`
	CreatedAt time.Time `json:"created_at"`
}

type PersonInput struct {
	Name     string `json:"name"`
	Color    string `json:"color"`
	Icon     string `json:"icon"`
	Archived bool   `json:"archived"`
}

type ExpenseShare struct {
	ID            string  `json:"id"`
	PersonID      string  `json:"person_id"`
	Person        *Person `json:"person,omitempty"`
	Amount        float64 `json:"amount"`
	PaidAmount    float64 `json:"paid_amount"`
	PendingAmount float64 `json:"pending_amount"`
	Settled       bool    `json:"settled"`
}

type ExpenseShareInput struct {
	PersonID string  `json:"person_id"`
	Amount   float64 `json:"amount"`
}

type PersonPayment struct {
	ID          string              `json:"id"`
	PersonID    string              `json:"person_id"`
	Amount      float64             `json:"amount"`
	PaidAt      string              `json:"paid_at"`
	Note        string              `json:"note"`
	Allocations []PaymentAllocation `json:"allocations"`
	CreatedAt   time.Time           `json:"created_at"`
}

type PaymentAllocation struct {
	ID        string  `json:"id"`
	PaymentID string  `json:"payment_id"`
	ShareID   string  `json:"share_id"`
	Amount    float64 `json:"amount"`
}

type SharedPersonSummary struct {
	Person       Person     `json:"person"`
	SharedTotal  float64    `json:"shared_total"`
	PaidTotal    float64    `json:"paid_total"`
	PendingTotal float64    `json:"pending_total"`
	LastActivity *time.Time `json:"last_activity,omitempty"`
}

type SharedSummary struct {
	PendingTotal float64               `json:"pending_total"`
	PeopleCount  int                   `json:"people_count"`
	People       []SharedPersonSummary `json:"people"`
}

type PersonShareExpense struct {
	Share   ExpenseShare `json:"share"`
	Expense Expense      `json:"expense"`
}

type Expense struct {
	ID                 string         `json:"id"`
	UserID             string         `json:"user_id"`
	CategoryID         string         `json:"category_id"`
	CardID             *string        `json:"card_id"`
	Amount             float64        `json:"amount"`
	Description        string         `json:"description"`
	ExpenseDate        time.Time      `json:"expense_date"`
	Source             string         `json:"source"`
	ReceiptURL         string         `json:"receipt_url,omitempty"`
	AudioURL           string         `json:"audio_url,omitempty"`
	TransactionGroupID *string        `json:"transaction_group_id"`
	CreatedAt          time.Time      `json:"created_at"`
	Category           *Category      `json:"category,omitempty"`
	Card               *Card          `json:"card,omitempty"`
	Shares             []ExpenseShare `json:"shares,omitempty"`
}

type ExpenseInput struct {
	CategoryID         string              `json:"category_id"`
	CardID             *string             `json:"card_id"`
	Amount             float64             `json:"amount"`
	Description        string              `json:"description"`
	ExpenseDate        string              `json:"expense_date"`
	Source             string              `json:"source"`
	TransactionGroupID *string             `json:"transaction_group_id"`
	Shares             []ExpenseShareInput `json:"shares,omitempty"`
}

type StatsSummary struct {
	Total      float64         `json:"total"`
	CashCount  int             `json:"cash_count"`
	CardCount  int             `json:"card_count"`
	ByCategory []CategoryTotal `json:"by_category"`
	ByPayment  []PaymentTotal  `json:"by_payment"`
	ByMonth    []MonthTotal    `json:"by_month"`
}

type PaymentTotal struct {
	CardID    *string `json:"card_id"`
	Name      string  `json:"name"`
	Franchise string  `json:"franchise"`
	Color     string  `json:"color"`
	Total     float64 `json:"total"`
	Count     int     `json:"count"`
}

type CategoryTotal struct {
	CategoryID   string  `json:"category_id"`
	CategoryName string  `json:"category_name"`
	Total        float64 `json:"total"`
	Count        int     `json:"count"`
	Icon         string  `json:"icon"`
	Color        string  `json:"color"`
	Type         int     `json:"type"`
}

type MonthTotal struct {
	Month string  `json:"month"`
	Total float64 `json:"total"`
}

type AIParsedExpense struct {
	Amount      float64 `json:"amount"`
	Description string  `json:"description"`
	Date        string  `json:"date"`
	Category    string  `json:"category"`
}
