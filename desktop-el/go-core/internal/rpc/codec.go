package rpc

import (
	"bufio"
	"encoding/json"
	"errors"
	"io"
)

type Decoder struct {
	reader *bufio.Reader
}

func NewDecoder(r io.Reader) *Decoder {
	return &Decoder{
		reader: bufio.NewReader(r),
	}
}

func (d *Decoder) DecodeRequest() (Request, error) {
	var req Request
	if err := d.decode(&req); err != nil {
		return Request{}, err
	}
	return req, nil
}

func (d *Decoder) DecodeResponse() (Response, error) {
	var res Response
	if err := d.decode(&res); err != nil {
		return Response{}, err
	}
	return res, nil
}

func (d *Decoder) DecodeEvent() (Event, error) {
	var evt Event
	if err := d.decode(&evt); err != nil {
		return Event{}, err
	}
	return evt, nil
}

func (d *Decoder) decode(target any) error {
	line, err := d.reader.ReadBytes('\n')
	if err != nil {
		if errors.Is(err, io.EOF) && len(line) == 0 {
			return io.EOF
		}
		if !errors.Is(err, io.EOF) {
			return err
		}
	}

	if err := json.Unmarshal(line, target); err != nil {
		return errors.Join(ErrInvalidJSON, err)
	}
	return nil
}

type Encoder struct {
	writer io.Writer
}

func NewEncoder(w io.Writer) *Encoder {
	return &Encoder{
		writer: w,
	}
}

func (e *Encoder) EncodeRequest(req Request) error {
	return e.encode(req)
}

func (e *Encoder) EncodeResponse(res Response) error {
	return e.encode(res)
}

func (e *Encoder) EncodeEvent(evt Event) error {
	return e.encode(evt)
}

func (e *Encoder) encode(v any) error {
	payload, err := json.Marshal(v)
	if err != nil {
		return err
	}
	payload = append(payload, '\n')
	_, err = e.writer.Write(payload)
	return err
}
